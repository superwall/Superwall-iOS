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
  private let urlSession: URLSession
  private let factory: ApiFactory

  init(factory: ApiFactory, urlSession: URLSession = URLSession(configuration: .default)) {
    self.factory = factory
    self.urlSession = urlSession
  }

  @discardableResult
  func request<Kind, Response>(
    _ endpoint: Endpoint<Kind, Response>,
    data: Kind.RequestData,
    onRequestStarted: (() -> Void)? = nil,
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
      if let onRequestStarted = onRequestStarted {
        return try await self.data(for: request, onRequestStarted: onRequestStarted)
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

  /// Uses an explicit task only when a caller needs the post-resume hook. The
  /// ordinary request path keeps Foundation's native async implementation.
  private func data(
    for request: URLRequest,
    onRequestStarted: () -> Void
  ) async throws -> (Data, URLResponse) {
    let state = RequestTaskState()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let task = urlSession.dataTask(with: request) { data, response, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let data = data, let response = response {
            continuation.resume(returning: (data, response))
          } else {
            continuation.resume(throwing: NetworkError.unknown)
          }
        }
        if state.resume(task) {
          onRequestStarted()
        }
      }
    } onCancel: {
      state.cancel()
    }
  }

  /// Cancellation can arrive before the data task exists, including a retry's
  /// timeout. Serialize registration/resume with cancellation so no task escapes.
  private final class RequestTaskState: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var isCancelled = false

    func resume(_ task: URLSessionDataTask) -> Bool {
      lock.lock()
      defer { lock.unlock() }
      self.task = task
      if isCancelled {
        task.cancel()
      }
      task.resume()
      return !isCancelled
    }

    func cancel() {
      lock.lock()
      isCancelled = true
      let task = task
      lock.unlock()
      task?.cancel()
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
