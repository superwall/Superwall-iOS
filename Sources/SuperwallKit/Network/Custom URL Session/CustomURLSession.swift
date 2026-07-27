//
//  URLSession+Request.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//
// swiftlint:disable function_body_length

import UIKit

enum NetworkError: LocalizedError, Equatable {
  case unknown
  case notAuthenticated
  case decoding
  case notFound
  case invalidUrl
  case noInternet

  /// The server responded with a status code outside the 2xx range that isn't
  /// covered by a more specific case.
  case http(statusCode: Int)

  var errorDescription: String? {
    switch self {
    case .unknown: return NSLocalizedString("An unknown error occurred.", comment: "")
    case .notAuthenticated: return NSLocalizedString("Unauthorized.", comment: "")
    case .decoding: return NSLocalizedString("Decoding error.", comment: "")
    case .notFound: return NSLocalizedString("Not found", comment: "")
    case .invalidUrl: return NSLocalizedString("URL invalid", comment: "")
    case .noInternet: return NSLocalizedString("No Internet", comment: "")
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

  init(factory: ApiFactory) {
    self.factory = factory
  }

  @discardableResult
  func request<Kind, Response>(
    _ endpoint: Endpoint<Kind, Response>,
    data: Kind.RequestData,
    isRetryingCallback: ((Int) -> Void)? = nil
  ) async throws -> Response {
    guard let request = await endpoint.makeRequest(
      with: data,
      factory: factory
    ) else {
      throw NetworkError.unknown
    }
    let auth = request.allHTTPHeaderFields?["Authorization"]

    Logger.debug(
      logLevel: .debug,
      scope: .network,
      message: "Request Started",
      info: [
        "body": String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "none",
        "url": request.url?.absoluteString ?? "unknown"
      ]
    )

    let startTime = Date().timeIntervalSince1970
    let (data, response) = try await Task.retrying(
      maxRetryCount: endpoint.retryCount,
      retryInterval: endpoint.retryInterval,
      timeout: endpoint.timeout,
      isRetryingCallback: isRetryingCallback
    ) {
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
