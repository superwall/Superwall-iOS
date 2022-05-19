//
//  URLSession+Request.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

extension URLSession {
  enum NetworkError: LocalizedError {
    case unknown
    case notAuthenticated
    case decoding
    case notFound
    case invalidUrl

    var errorDescription: String? {
      switch self {
      case .unknown: return NSLocalizedString("An unknown error occurred.", comment: "")
      case .notAuthenticated: return NSLocalizedString("Unauthorized.", comment: "")
      case .decoding: return NSLocalizedString("Decoding error.", comment: "")
      case .notFound: return NSLocalizedString("Not found", comment: "")
      case .invalidUrl: return NSLocalizedString("URL invalid", comment: "")
      }
    }
  }

  // swiftlint:disable:next function_body_length
  func request<Response>(
    _ endpoint: Endpoint<Response>,
    isForDebugging: Bool = false,
    completion: @escaping (Result<Response, Error>) -> Void
  ) {
    guard let request = endpoint.makeRequest(forDebugging: isForDebugging) else {
      return completion(.failure(NetworkError.unknown))
    }
    guard let auth = request.allHTTPHeaderFields?["Authorization"] else {
      return completion(.failure(NetworkError.notAuthenticated))
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

    let task = dataTask(with: request) { data, response, error in
      let requestDuration = Date().timeIntervalSince1970 - startTime

      do {
        guard let data = data else {
          return completion(.failure(error ?? NetworkError.unknown))
        }
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
              ],
              error: error
            )
            return completion(.failure(NetworkError.notAuthenticated))
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
              ],
              error: error
            )
            return completion(.failure(NetworkError.notFound))
          }
        }

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

        let response = try JSONDecoder.endpoint.decode(
          Response.self,
          from: data
        )

        completion(.success(response))
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Error",
          info: [
            "request": request.debugDescription,
            "api_key": auth,
            "url": request.url?.absoluteString ?? "unknown",
            "message": "Unable to decode response to type \(Response.self)",
            "info": String(decoding: data ?? Data(), as: UTF8.self),
            "request_duration": requestDuration
          ],
          error: error
        )
        completion(.failure(NetworkError.decoding))
      }
    }
    task.resume()
  }
}
