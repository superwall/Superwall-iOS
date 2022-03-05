//
//  ModelLoader.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

final class ModelLoader {
  func getEvents(
    events: EventsRequest,
    completion: @escaping (Result<EventsResponse, Swift.Error>) -> Void
  ) {
    Network2.shared.send(.events(eventsRequest: events)) { result in
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
    completion: @escaping (Result<PaywallResponse, Swift.Error>) -> Void
  ) {
    Network2.shared.send(
      .paywall(
        withIdentifier: identifier,
        fromEvent: event)
    ) { result in
      switch result {
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
      case .success(let response):
        completion(.success(response))
      }
    }
  }
}
