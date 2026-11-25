//
//  URLSession+Request.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//
// swiftlint:disable function_body_length

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum NetworkError: LocalizedError, Equatable {
  case unknown
  case notAuthenticated
  case decoding
  case notFound
  case invalidUrl
  case noInternet
  /// The app turned off event tracking, so the request wasn't sent.
  case trackingDisabled

  /// The server responded with a status code outside the 2xx range that isn't
  /// covered by a more specific case.
  case http(statusCode: Int)
  /// The response's `X-Superwall-Signature` didn't verify, while
  /// ``SuperwallOptions/shouldEnforceResponseSignatures`` is on.
  case invalidResponseSignature

  var errorDescription: String? {
    switch self {
    case .unknown: return NSLocalizedString("An unknown error occurred.", comment: "")
    case .notAuthenticated: return NSLocalizedString("Unauthorized.", comment: "")
    case .decoding: return NSLocalizedString("Decoding error.", comment: "")
    case .notFound: return NSLocalizedString("Not found", comment: "")
    case .invalidUrl: return NSLocalizedString("URL invalid", comment: "")
    case .noInternet: return NSLocalizedString("No Internet", comment: "")
    case .trackingDisabled: return NSLocalizedString("Event tracking turned off", comment: "")
    case .invalidResponseSignature:
      return NSLocalizedString("The response signature didn't verify.", comment: "")
    case .http(let statusCode):
      return String(
        format: NSLocalizedString("HTTP error %d.", comment: ""),
        statusCode
      )
    }
  }

  /// The error a response with the given status code should surface as, or `nil` if
  /// the response was successful.
  static func make(fromStatusCode statusCode: Int) -> NetworkError? {
    switch statusCode {
    case 200...299: return nil
    case 401: return .notAuthenticated
    case 404: return .notFound
    default: return .http(statusCode: statusCode)
    }
  }

  /// The message logged when a request fails with this error.
  var logMessage: String {
    switch self {
    case .notAuthenticated: return "Unable to Authenticate"
    case .notFound: return "Not Found"
    default: return "Request Failed"
    }
  }
}

class CustomURLSession {
  private let urlSession = URLSession(configuration: .default)
  private let factory: ApiFactory
  /// Shared so verified signing keys are cached across requests.
  private let responseVerifier = ResponseVerifier()

  init(factory: ApiFactory) {
    self.factory = factory
  }

  /// Keys whose values are the device's public IP addresses. They're sent,
  /// but never logged, since logs reach the app's logging delegate.
  private static let ipAddressKeys: Set<String> = ["ipV4", "ipV6", "$ipV4", "$ipV6"]

  /// The request body as text for the logs, with IP addresses redacted.
  static func loggableBody(_ body: Data?) -> String {
    guard let body = body else {
      return "none"
    }
    // Most bodies carry no address, so only those that might are parsed.
    guard
      body.range(of: Data("ipV".utf8)) != nil,
      let json = try? JSONSerialization.jsonObject(with: body),
      let redacted = try? JSONSerialization.data(
        withJSONObject: redactingIPAddresses(in: json),
        options: [.sortedKeys]
      )
    else {
      return String(data: body, encoding: .utf8) ?? "none"
    }
    return String(data: redacted, encoding: .utf8) ?? "none"
  }

  private static func redactingIPAddresses(in value: Any) -> Any {
    if let dictionary = value as? [String: Any] {
      var result: [String: Any] = [:]
      for (key, child) in dictionary {
        result[key] = ipAddressKeys.contains(key) ? "<redacted>" : redactingIPAddresses(in: child)
      }
      return result
    }
    if let array = value as? [Any] {
      return array.map { redactingIPAddresses(in: $0) }
    }
    return value
  }

  @discardableResult
  func request<Kind, Response>(
    _ endpoint: Endpoint<Kind, Response>,
    data: Kind.RequestData,
    isRetryingCallback: ((Int) -> Void)? = nil
  ) async throws -> Response {
    guard var request = await endpoint.makeRequest(
      with: data,
      factory: factory
    ) else {
      throw NetworkError.unknown
    }
    let nonce = endpoint.signedAs.map { ResponseSignatureCheck.prepare(&request, for: $0) } ?? ""
    let auth = request.allHTTPHeaderFields?["Authorization"]

    Logger.debug(
      logLevel: .debug,
      scope: .network,
      message: "Request Started",
      info: [
        "body": Self.loggableBody(request.httpBody),
        "url": request.url?.absoluteString ?? "unknown"
      ]
    )

    let startTime = Date().timeIntervalSince1970
    let canSend = endpoint.canSend
    let (data, response) = try await Task.retrying(
      maxRetryCount: endpoint.retryCount,
      retryInterval: endpoint.retryInterval,
      timeout: endpoint.timeout,
      isRetryingCallback: isRetryingCallback
    ) {
      if let canSend = canSend,
        !canSend() {
        throw NetworkError.trackingDisabled
      }
      return try await self.urlSession.data(for: request)
    }.value

    let requestDuration = Date().timeIntervalSince1970 - startTime
    let requestId = try getRequestId(
      from: request,
      checkingValidityOf: response,
      withAuth: auth,
      requestDuration: requestDuration
    )

    Logger.debug(
      logLevel: .debug,
      scope: .network,
      message: "Request Completed",
      info: [
        "request": request.debugDescription,
        "api_key": auth ?? "N/A",
        "url": request.url?.absoluteString ?? "unknown",
        "request_id": requestId,
        "request_duration": requestDuration
      ]
    )

    if let signedAs = endpoint.signedAs {
      try await checkSignature(
        of: response,
        data: data,
        signedAs: signedAs,
        request: request,
        nonce: nonce
      )
    }

    guard let value = try? Kind.jsonDecoder.decode(
      Response.self,
      from: data
    ) else {
      let networkDecodingFail = InternalSuperwallEvent.NetworkDecodingFail(
        requestURLString: request.url?.absoluteString ?? "",
        responseString: String(data: data, encoding: .utf8) ?? ""
      )
      await Superwall.shared.track(networkDecodingFail)
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Error",
        info: [
          "request": request.debugDescription,
          "api_key": auth ?? "N/A",
          "url": request.url?.absoluteString ?? "unknown",
          "message": "Unable to decode response to type \(Response.self)",
          "info": String(data: data, encoding: .utf8) ?? "",
          "request_duration": requestDuration
        ]
      )
      throw NetworkError.decoding
    }

    return value
  }

  /// Verifies the response's `X-Superwall-Signature`. Reports a failure; throws only when
  /// signatures are enforced.
  private func checkSignature(
    of response: URLResponse,
    data: Data,
    signedAs: SignedResponse,
    request: URLRequest,
    nonce: String
  ) async throws {
    let enforce = factory.configManager.options.shouldEnforceResponseSignatures
    let result: ResponseVerifier.Result
    if let context = ResponseSignatureCheck.context(for: signedAs, request: request, nonce: nonce) {
      // Two headers arrive comma-joined, which the parser rejects as a duplicate member.
      let header = (response as? HTTPURLResponse)?
        .value(forHTTPHeaderField: SignatureEnvelope.signatureHeader)
      result = responseVerifier.verify(
        header: header,
        context: context,
        body: data,
        now: Int64(Date().timeIntervalSince1970)
      )
    } else {
      result = .failed(.malformedHeader)
    }

    let reason: String
    switch ResponseSignatureCheck.decide(result, enforce: enforce) {
    case .accept:
      return
    case .report(let failure),
      .reject(let failure):
      reason = failure
    }
    Logger.debug(
      logLevel: enforce ? .error : .warn,
      scope: .network,
      message: "Response signature didn't verify",
      info: [
        "endpoint": signedAs.endpoint.rawValue,
        "reason": reason,
        "enforced": enforce
      ]
    )
    await Superwall.shared.track(
      ResponseSignatureFailure(endpoint: signedAs.endpoint, reason: reason, isEnforced: enforce)
    )
    if enforce {
      throw NetworkError.invalidResponseSignature
    }
  }

  private func getRequestId(
    from request: URLRequest,
    checkingValidityOf response: URLResponse,
    withAuth auth: String?,
    requestDuration: TimeInterval
  ) throws -> String {
    var requestId = "unknown"

    if let response = response as? HTTPURLResponse {
      if let id = response.allHeaderFields["x-request-id"] as? String {
        requestId = id
      }

      // Any non-2xx response is surfaced as an error. Without this, error responses
      // fall through to decoding and are reported as `.decoding`, which describes
      // the wrong failure and logs them as decoding failures.
      if let error = NetworkError.make(fromStatusCode: response.statusCode) {
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: error.logMessage,
          info: [
            "request": request.debugDescription,
            "api_key": auth ?? "N/A",
            "url": request.url?.absoluteString ?? "unknown",
            "status_code": response.statusCode,
            "request_id": requestId,
            "request_duration": requestDuration
          ]
        )
        throw error
      }
    }

    return requestId
  }
}
