//
//  File.swift
//
//
//  Created by Brian Anglin on 2/3/21.
//
import UIKit
import Foundation

class Network {
  var userId: String?
  static let shared = Network()
  let urlSession = URLSession(configuration: .ephemeral)
  var hostDomain: String {
    switch Paywall.networkEnvironment {
    case .release:
      return "superwall.me"
    case .releaseCandidate:
      return "superwallcanary.com"
    case .developer:
      return "superwall.dev"
    }
  }

  var baseURL: URL {
    // swiftlint:disable:next force_unwrapping
    return URL(string: "https://api.\(hostDomain)/api/v1/")!
  }

  var analyticsBaseURL: URL {
    // swiftlint:disable:next force_unwrapping
    return URL(string: "https://collector.\(hostDomain)/api/v1/")!
  }
}

extension Network {
  enum Error: LocalizedError {
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
}

// MARK: Private extension for actually making requests
extension Network {
  // swiftlint:disable:next function_body_length
  func send<ResponseType: Decodable>(
    _ request: URLRequest,
    isDebugRequest: Bool = false,
    completion: @escaping (Result<ResponseType, Swift.Error>) -> Void
  ) {
    var request = request
    Logger.debug(
      logLevel: .debug,
      scope: .network,
      message: "Request Started",
      info: [
        "body": String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "none",
        "url": request.url?.absoluteString ?? "unknown"
      ],
      error: nil
    )
    let startTime = Date().timeIntervalSince1970
    let requestId = UUID().uuidString

    let auth = "Bearer " + (isDebugRequest ? (Store.shared.debugKey ?? "") : Store.shared.apiKey)
    request.setValue(auth, forHTTPHeaderField: "Authorization")
    request.setValue("iOS", forHTTPHeaderField: "X-Platform")
    request.setValue("SDK", forHTTPHeaderField: "X-Platform-Environment")
    request.setValue(Store.shared.appUserId ?? "", forHTTPHeaderField: "X-App-User-ID")
    request.setValue(Store.shared.aliasId ?? "", forHTTPHeaderField: "X-Alias-ID")
    request.setValue(DeviceHelper.shared.vendorId, forHTTPHeaderField: "X-Vendor-ID")
    request.setValue(DeviceHelper.shared.appVersion, forHTTPHeaderField: "X-App-Version")
    request.setValue(DeviceHelper.shared.osVersion, forHTTPHeaderField: "X-OS-Version")
    request.setValue(DeviceHelper.shared.model, forHTTPHeaderField: "X-Device-Model")
    request.setValue(DeviceHelper.shared.locale, forHTTPHeaderField: "X-Device-Locale") // en_US, en_GB
    request.setValue(DeviceHelper.shared.languageCode, forHTTPHeaderField: "X-Device-Language-Code") // en
    request.setValue(DeviceHelper.shared.currencyCode, forHTTPHeaderField: "X-Device-Currency-Code") // USD
    request.setValue(DeviceHelper.shared.currencySymbol, forHTTPHeaderField: "X-Device-Currency-Symbol") // $
    request.setValue(DeviceHelper.shared.secondsFromGMT, forHTTPHeaderField: "X-Device-Timezone-Offset") // $
    request.setValue(DeviceHelper.shared.appInstallDate, forHTTPHeaderField: "X-App-Install-Date") // $
		request.setValue(DeviceHelper.shared.radioType, forHTTPHeaderField: "X-Radio-Type") // $
		request.setValue(DeviceHelper.shared.interfaceStyle, forHTTPHeaderField: "X-Device-Interface-Style") // $
		request.setValue(sdkVersion, forHTTPHeaderField: "X-SDK-Version")
		request.setValue(requestId, forHTTPHeaderField: "X-Request-Id")
		request.setValue(DeviceHelper.shared.bundleId, forHTTPHeaderField: "X-Bundle-ID")
		request.setValue(DeviceHelper.shared.isLowPowerModeEnabled, forHTTPHeaderField: "X-Low-Power-Mode")

    let task = self.urlSession.dataTask(with: request) { data, response, error in
      let requestDuration = Date().timeIntervalSince1970 - startTime

      do {
        guard let unWrappedData = data else {
          return completion(.failure(error ?? Error.unknown))
        }
				var requestId = "unknown"

				if let response = response as? HTTPURLResponse, let rid = response.allHeaderFields["x-request-id"] as? String {
					requestId = rid
				}

				if let response = response as? HTTPURLResponse {
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
						return completion(.failure(Error.notAuthenticated))
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
						return completion(.failure(Error.notFound))
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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ResponseType.self, from: unWrappedData)
        completion(.success(response))
      } catch {
				Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Error",
          info: [
            "request": request.debugDescription,
            "api_key": auth,
            "url": request.url?.absoluteString ?? "unkown",
            "message": "Unable to decode response to type \(ResponseType.self)",
            "info": String(decoding: data ?? Data(), as: UTF8.self),
            "request_duration": requestDuration
          ],
          error: error
        )
        completion(.failure(Error.decoding))
      }
    }
    task.resume()
  }
}

extension Network {
  func events(
    events: EventsRequest,
    completion: @escaping (Result<EventsResponse, Swift.Error>) -> Void
  ) {
    // swiftlint:disable:next force_unwrapping
    let components = URLComponents(string: "events")!
    // swiftlint:disable:next force_unwrapping
    let requestURL = components.url(relativeTo: analyticsBaseURL)!
    var request = URLRequest(url: requestURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    // Bail if we can't encode
    do {
      request.httpBody = try encoder.encode(events)
    } catch {
      return completion(.failure(Error.unknown))
    }

    send(request) { (result: Result<EventsResponse, Swift.Error>)  in
      switch result {
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /events",
          info: ["payload": events],
          error: error
        )
        completion(.failure(error))
      case .success(let response):
        completion(.success(response))
      }
    }
  }
}

extension Network {
	func paywall(
    withIdentifier: String? = nil,
    fromEvent event: EventData? = nil,
    completion: @escaping (Result<PaywallResponse, Swift.Error>) -> Void
  ) {
    // swiftlint:disable:next force_unwrapping
    let components = URLComponents(string: "paywall")!
    // swiftlint:disable:next force_unwrapping
    let requestURL = components.url(relativeTo: baseURL)!
    var request = URLRequest(url: requestURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    // Bail if we can't encode
    do {
			if let id = withIdentifier {
				let paywallRequest = ["identifier": id]
				request.httpBody = try encoder.encode(paywallRequest)
			} else if let event = event {
				let paywallRequest = ["event": event.jsonData]
				request.httpBody = try encoder.encode(paywallRequest)
			} else {
				let paywallRequest = PaywallRequest(appUserId: Store.shared.userId ?? "")
				request.httpBody = try encoder.encode(paywallRequest)
			}
    } catch {
      return completion(.failure(Error.unknown))
    }

    send(request) { (result: Result<PaywallResponse, Swift.Error>)  in
      switch result {
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /paywall",
          info: ["identifier": withIdentifier ?? "none", "event": event.debugDescription],
          error: error
        )
        completion(.failure(error))
      case .success(let response):
        completion(.success(response))
      }
    }
  }
}

extension Network {
  func paywalls(completion: @escaping (Result<PaywallsResponse, Swift.Error>) -> Void) {
    // swiftlint:disable:next force_unwrapping
    let components = URLComponents(string: "paywalls")!
    // swiftlint:disable:next force_unwrapping
    let requestURL = components.url(relativeTo: baseURL)!
    var request = URLRequest(url: requestURL)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    send(request, isDebugRequest: true) { (result: Result<PaywallsResponse, Swift.Error>)  in
      switch result {
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /paywalls",
          info: nil,
          error: error
        )
        completion(.failure(error))
      case .success(let response):
        completion(.success(response))
      }
    }
  }
}

extension Network {
  func config(completion: @escaping (Result<ConfigResponse, Swift.Error>) -> Void) {
    // swiftlint:disable:next force_unwrapping
    let components = URLComponents(string: "config")!
    // swiftlint:disable:next force_unwrapping
    let requestURL = components.url(relativeTo: baseURL)!
    var request = URLRequest(url: requestURL)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    send(request, isDebugRequest: false) { (result: Result<ConfigResponse, Swift.Error>)  in
      switch result {
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /config",
          info: nil,
          error: error
        )
        completion(.failure(error))
      case .success(let response):
        completion(.success(response))
      }
    }
  }
}

extension Network {
  func confirmAssignments(
    confirmAssignments: ConfirmAssignments,
    completion: ( ((Result<ConfirmAssignmentResponse, Swift.Error>)) -> Void)?
  ) {
    // swiftlint:disable:next force_unwrapping
    let components = URLComponents(string: "confirm_assignments")!
    // swiftlint:disable:next force_unwrapping
    let requestURL = components.url(relativeTo: baseURL)!
    var request = URLRequest(url: requestURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    // Bail if we can't encode
    do {
      request.httpBody = try encoder.encode(confirmAssignments)
    } catch {
      completion?(.failure(Error.unknown))
      return
    }
    send(request) { (result: Result<ConfirmAssignmentResponse, Swift.Error>)  in
      switch result {
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /confirm_assignments",
          info: ["assignments": confirmAssignments],
          error: error
        )
        completion?(.failure(error))
      case .success(let response):
        completion?(.success(response))
      }
    }
  }
}

extension Network {
	func postback(
    _ postback: Postback,
    completion: @escaping (Result<PostBackResponse, Swift.Error>) -> Void
  ) {
    // swiftlint:disable:next force_unwrapping
		let components = URLComponents(string: "postback")!
    // swiftlint:disable:next force_unwrapping
		let requestURL = components.url(relativeTo: baseURL)!
		var request = URLRequest(url: requestURL)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase

		// Bail if we can't encode
		do {
			request.httpBody = try encoder.encode(postback)
		} catch {
			return completion(.failure(Error.unknown))
		}

		send(request) { (result: Result<PostBackResponse, Swift.Error>)  in
      switch result {
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /postback",
          info: ["payload": postback],
          error: error
        )
        completion(.failure(error))
      case .success(let response):
        completion(.success(response))
      }
		}
	}
  // swiftlint:disable:next file_length
}
