//
//  ModelLoader.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation
import UIKit
import Combine

class Network {
  private let urlSession: CustomURLSession
  private var applicationStatePublisher: AnyPublisher<UIApplication.State, Never> {
    UIApplication.shared.publisher(for: \.applicationState)
      .eraseToAnyPublisher()
  }
  private let factory: ApiFactory

  init(
    urlSession: CustomURLSession = CustomURLSession(),
    factory: ApiFactory
  ) {
    self.urlSession = urlSession
    self.factory = factory
  }

  func sendEvents(events: EventsRequest) async {
    do {
      let result = try await urlSession.request(.events(eventsRequest: events, factory: factory))
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

  func getPaywall(
    withId identifier: String? = nil,
    fromEvent event: EventData? = nil
  ) async throws -> Paywall {
    do {
      return try await urlSession.request(
        .paywall(withIdentifier: identifier, fromEvent: event, factory: factory)
      )
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

  func getPaywalls() async throws -> [Paywall] {
    do {
      let response = try await urlSession.request(.paywalls(factory: factory))
      return response.paywalls
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

  @MainActor
  func getConfig(
    injectedApplicationStatePublisher: (AnyPublisher<UIApplication.State, Never>)? = nil
  ) async throws -> Config {
    // Suspend until app is in foreground.
    let applicationStatePublisher = injectedApplicationStatePublisher ?? self.applicationStatePublisher

    await applicationStatePublisher
      .subscribe(on: DispatchQueue.main)
      .filter { $0 != .background }
      .eraseToAnyPublisher()
      .async()

    do {
      let requestId = UUID().uuidString
      var config = try await urlSession.request(.config(requestId: requestId, factory: factory))
      config.requestId = requestId
      return config
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

  func confirmAssignments(_ confirmableAssignments: AssignmentPostback) async {
    do {
      try await urlSession.request(.confirmAssignments(confirmableAssignments, factory: factory))
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
      let result = try await urlSession.request(.assignments(factory: factory))
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
      let result = try await urlSession.request(.sessionEvents(session, factory: factory))
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
      try await urlSession.request(.assignments(factory: factory))
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
