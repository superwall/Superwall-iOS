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
        if identifier == nil {
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
        } else {
          Logger.debug(
            logLevel: .error,
            scope: .network,
            message: "Request Failed: /paywall/:identifier",
            info: nil,
            error: error
          )
        }
        completion(.failure(error))
      }
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

  func confirmAssignments(
    _ confirmableAssignments: ConfirmableAssignments,
    completion: (((Result<ConfirmedAssignmentResponse, Error>)) -> Void)?
  ) {
    urlSession.request(.confirmAssignments(confirmableAssignments)) { result in
      switch result {
      case .success(let response):
        completion?(.success(response))
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /confirm_assignments",
          info: ["assignments": confirmableAssignments],
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
