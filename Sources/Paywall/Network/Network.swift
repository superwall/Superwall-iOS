//
//  ModelLoader.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation
import UIKit

class Network {
  static let shared = Network()
  private let urlSession: CustomURLSession

  /// Only use init when testing, for all other times use `Network.shared`.
  init(urlSession: CustomURLSession = CustomURLSession()) {
    self.urlSession = urlSession
  }

  func sendEvents(events: EventsRequest) {
    urlSession.request(.events(eventsRequest: events)) { result in
      switch result {
      case .success(let response):
        switch response.status {
        case .ok:
          break
        case .partialSuccess:
          Logger.debug(
            logLevel: .warn,
            scope: .network,
            message: "Request had partial success: /events",
            info: ["payload": response.invalidIndexes as Any]
          )
        }
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /events",
          info: ["payload": events],
          error: error
        )
      }
    }
  }

  func getPaywallResponse(
    withPaywallId identifier: String? = nil,
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
          error: error
        )
        completion(.failure(error))
      }
    }
  }

  func getConfig(
    withRequestId requestId: String,
    completion: @escaping (Result<Config, Error>) -> Void,
    applicationState: UIApplication.State = UIApplication.shared.applicationState,
    storage: Storage = Storage.shared
  ) {
    if applicationState == .background {
      let configRequest = ConfigRequest(
        id: requestId,
        completion: completion
      )
      storage.configRequest = configRequest
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "/config request called from a background state. This will fire when the app enters an active state."
      )
      return
    }

    urlSession.request(.config(requestId: requestId)) { result in
      switch result {
      case .success(let response):
        completion(.success(response))
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /config",
          error: error
        )
        completion(.failure(error))
      }
    }
  }

  func confirmAssignments(_ confirmableAssignments: ConfirmableAssignments) {
    urlSession.request(.confirmAssignments(confirmableAssignments)) { result in
      switch result {
      case .success:
        break
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /confirm_assignments",
          info: ["assignments": confirmableAssignments],
          error: error
        )
      }
    }
  }

  func sendSessionEvents(_ session: SessionEventsRequest) {
    urlSession.request(.sessionEvents(session)) { result in
      switch result {
      case .success(let response):
        switch response.status {
        case .ok:
          break
        case .partialSuccess:
          Logger.debug(
            logLevel: .warn,
            scope: .network,
            message: "Request had partial success: /session_events",
            info: ["payload": response.invalidIndexes as Any]
          )
        }
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /session_events",
          info: ["payload": session],
          error: error
        )
      }
    }
  }

  func sendPostback(_ postback: Postback) {
    urlSession.request(.postback(postback)) { result in
      switch result {
      case .success:
        break
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .network,
          message: "Request Failed: /postback",
          info: ["payload": postback],
          error: error
        )
      }
    }
  }
}
