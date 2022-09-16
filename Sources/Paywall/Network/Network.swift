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

  func sendEvents(events: EventsRequest) async {
    do {
      let result = try await urlSession.request(.events(eventsRequest: events))
      switch result.status {
      case .ok:
        break
      case .partialSuccess:
        Logger.debug(
          logLevel: .warn,
          scope: .network,
          message: "Request had partial success: /events",
          info: ["payload": result.invalidIndexes as Any]
        )
      }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /events",
        info: ["payload": events],
        error: error
      )
    }
  }

  func getPaywallResponse(
    withPaywallId identifier: String? = nil,
    fromEvent event: EventData? = nil
  ) async throws -> PaywallResponse {
    do {
      return try await urlSession.request(.paywall(withIdentifier: identifier, fromEvent: event))
    } catch {
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
      throw error
    }
  }

  func getPaywalls() async throws -> PaywallsResponse {
    do {
      return try await urlSession.request(.paywalls(), isForDebugging: true)
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /paywalls",
        error: error
      )
      throw error
    }
  }

    func getConfig(
      withRequestId requestId: String,
      configManager: ConfigManager = .shared
    ) async throws -> Config {
    do {
      try await urlSession.request(.config(requestId: requestId))
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /static_config",
        error: error
      )
      throw error
    }
  }

  func confirmAssignments(_ confirmableAssignments: ConfirmableAssignments) async {
    do {
      try await urlSession.request(.confirmAssignments(confirmableAssignments))
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /confirm_assignments",
        info: ["assignments": confirmableAssignments],
        error: error
      )
    }
  }

  func getAssignments() async throws -> [Assignment] {
    do {
      let result = try await urlSession.request(.assignments)
      return result.assignments
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /assignments",
        error: error
      )
      throw error
    }
  }

  func sendSessionEvents(_ session: SessionEventsRequest) async {
    do {
      let result = try await urlSession.request(.sessionEvents(session))
      switch result.status {
      case .ok:
        break
      case .partialSuccess:
        Logger.debug(
          logLevel: .warn,
          scope: .network,
          message: "Request had partial success: /session_events",
          info: ["payload": result.invalidIndexes as Any]
        )
      }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .network,
        message: "Request Failed: /session_events",
        info: ["payload": session],
        error: error
      )
    }
  }

  func sendPostback(_ postback: Postback) async {
    do {
      try await urlSession.request(.assignments)
    } catch {
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
