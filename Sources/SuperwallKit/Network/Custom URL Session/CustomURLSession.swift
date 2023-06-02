//
//  URLSession+Request.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

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

  @discardableResult
  func request<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
    guard let request = await endpoint.makeRequest() else {
      throw NetworkError.unknown
    }
    guard let auth = request.allHTTPHeaderFields?["Authorization"] else {
      throw NetworkError.notAuthenticated
    }

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
    let (data, response) = try await Task.retrying(maxRetryCount: endpoint.retryCount) {
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
        "api_key": auth,
        "url": request.url?.absoluteString ?? "unknown",
        "request_id": requestId,
        "request_duration": requestDuration
      ]
    )

    guard let value = try? JSONDecoder.fromSnakeCase.decode(
      Response.self,
      from: data
    ) else {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Error",
        info: [
          "request": request.debugDescription,
          "api_key": auth,
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
    withAuth auth: String,
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
            "api_key": auth,
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
            "api_key": auth,
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
