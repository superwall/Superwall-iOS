//
//  ModelLoader.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

final class Network {
  static let shared = Network()
  private let urlSession = URLSession(configuration: .ephemeral)

  func sendEvents(
    events: EventsRequest,
    completion: @escaping (Result<EventsResponse, Error>) -> Void
  ) {
    urlSession.request(.events(eventsRequest: events)) { result in
      switch result {
      case .success(let response):
        completion(.success(response))
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /events",
          info: ["payload": events],
          error: error
        )
        completion(.failure(error))
      }
    }
  }

  func getPaywall(
    withIdentifier identifier: String? = nil,
    fromEvent event: EventData? = nil,
    completion: @escaping (Result<PaywallResponse, Error>) -> Void
  ) {
    urlSession.request(
      .paywall(
        withIdentifier: identifier,
        fromEvent: event
      )
    ) { result in
      switch result {
      case .success(let response):
        completion(.success(response))
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /paywall",
          info: [
            "identifier": identifier ?? "none",
            "event": event.debugDescription
          ],
          error: error
        )
        completion(.failure(error))
      }
    }
  }

  func paywallByIdentifier(identifier: String, completion: @escaping (Result<PaywallResponse, Swift.Error>) -> Void) {
        // WARNING: Do not modify anything about this request without considering our cache eviction code
        // we must know all the exact urls we need to invalidate so chaning the order, inclusion, etc of any query
        // parameters will cause issues
        var components = URLComponents(string: "paywall/\(identifier)")!
        let queryPk = URLQueryItem(name: "pk", value: Store.shared.apiKey ?? "")


        // In the config endpoint we return all the locales, this code will check if:
        // 1. The device locale (ex: en_US) exists in the locales list
        // 2. The shortend device locale (ex: en) exists in the locale list
        // If either exist (preferring the most specific) include the locale in the
        // the url as a query param.
        var queryLocale: URLQueryItem? = nil
        if Store.shared.locales.contains(DeviceHelper.shared.locale) {
            queryLocale = URLQueryItem(name: "locale", value: DeviceHelper.shared.locale)
        } else {
            let shortLocale = DeviceHelper.shared.locale.split(separator: "_")[0]
            if (Store.shared.locales.contains(String(shortLocale))) {
                queryLocale = URLQueryItem(name: "locale", value: String(shortLocale))
            }
        }
        if queryLocale != nil {
            components.queryItems = [queryPk, queryLocale!]
        } else {
            components.queryItems = [queryPk]
        }

        let requestURL = components.url(relativeTo: baseURL)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        send(request, completion: { (result: Result<PaywallResponse, Swift.Error>)  in
            switch result {
                case .failure(let error):
                    Logger.debug(logLevel: .error, scope: .network, message: "Request Failed: /paywall/:identifier", info: nil, error: error)
                    completion(.failure(error))
                case .success(let response):
                    completion(.success(response))
            }
        })
    }
  }
  
  func getPaywalls(completion: @escaping (Result<PaywallsResponse, Error>) -> Void) {
    urlSession.request(
      .paywalls(),
      isForDebugging: true
    ) { result in
      switch result {
      case .success(let response):
        completion(.success(response))
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /paywalls",
          info: nil,
          error: error
        )
        completion(.failure(error))
      }
    }
  }

  func getConfig(completion: @escaping (Result<ConfigResponse, Error>) -> Void) {
    urlSession.request(.config()) { result in
      switch result {
      case .success(let response):
        completion(.success(response))
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /config",
          info: nil,
          error: error
        )
        completion(.failure(error))
      }
    }
  }

  func sendConfirmedAssignments(
    _ confirmedAssignments: ConfirmedAssignments,
    completion: (((Result<ConfirmedAssignmentResponse, Error>)) -> Void)?
  ) {
    urlSession.request(.confirmedAssignment(confirmedAssignments)) { result in
      switch result {
      case .success(let response):
        completion?(.success(response))
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /confirm_assignments",
          info: ["assignments": confirmedAssignments],
          error: error
        )
        completion?(.failure(error))
      }
    }
  }

  func sendPostback(
    _ postback: Postback,
    completion: @escaping (Result<PostBackResponse, Error>) -> Void
  ) {
    urlSession.request(.postback(postback)) { result in
      switch result {
      case .success(let response):
        completion(.success(response))
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /postback",
          info: ["payload": postback],
          error: error
        )
        completion(.failure(error))
      }
    }
  }
}
