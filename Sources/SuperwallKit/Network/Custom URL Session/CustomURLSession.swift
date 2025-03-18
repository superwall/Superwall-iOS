//
//  URLSession+Request.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//
// swiftlint:disable function_body_length

import UIKit

enum NetworkError: LocalizedError {
  case unknown
  case notAuthenticated
  case decoding
  case notFound
  case invalidUrl
  case noInternet

  var errorDescription: String? {
    switch self {
    case .unknown: return NSLocalizedString("An unknown error occurred.", comment: "")
    case .notAuthenticated: return NSLocalizedString("Unauthorized.", comment: "")
    case .decoding: return NSLocalizedString("Decoding error.", comment: "")
    case .notFound: return NSLocalizedString("Not found", comment: "")
    case .invalidUrl: return NSLocalizedString("URL invalid", comment: "")
    case .noInternet: return NSLocalizedString("No Internet", comment: "")
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
      logLevel: .error,
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

    Logger.debug(
      logLevel: .error,
      scope: .network,
      message: "Raw Response Data",
      info: [
        "data": String(decoding: data, as: UTF8.self)
      ]
    )

    guard let value = try? Kind.jsonDecoder.decode(
      Response.self,
      from: data
    ) else {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Error",
        info: [
          "request": request.debugDescription,
          "api_key": auth ?? "N/A",
          "url": request.url?.absoluteString ?? "unknown",
          "message": "Unable to decode response to type \(Response.self)",
          "info": String(decoding: data, as: UTF8.self),
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

      if response.statusCode == 401 {
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Unable to Authenticate",
          info: [
            "request": request.debugDescription,
            "api_key": auth ?? "N/A",
            "url": request.url?.absoluteString ?? "unknown",
            "request_id": requestId,
            "request_duration": requestDuration
          ]
        )
        throw NetworkError.notAuthenticated
      }

      if response.statusCode == 404 {
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Not Found",
          info: [
            "request": request.debugDescription,
            "api_key": auth ?? "N/A",
            "url": request.url?.absoluteString ?? "unknown",
            "request_id": requestId,
            "request_duration": requestDuration
          ]
        )
        throw NetworkError.notFound
      }
    }

    return requestId
  }
}
