//
//  ModelLoader.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

final class ModelLoader {
  static let shared = ModelLoader()
  private let urlSession = URLSession(configuration: .ephemeral)

  func getEvents(
    events: EventsRequest,
    completion: @escaping (Result<EventsResponse, Error>) -> Void
  ) {
    urlSession.request(.events(eventsRequest: events)) { result in
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

  func paywall(
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
}
