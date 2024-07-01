//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//

import UIKit
import StoreKit
import Combine

actor TriggerSessionManager {
  /// The list of all potential trigger sessions, keyed by the trigger event name, created after receiving the config.
  private var pendingTriggerSessions: [String: TriggerSession] = [:]

  /// The active trigger session.
  var activeTriggerSession: TriggerSession?

  private unowned let configManager: ConfigManager

  /// A local count for transactions used within the trigger session.
  private var transactionCount: TriggerSession.Transaction.Count?

  @MainActor
  private var observerCancellables: [AnyCancellable] = []
  private var configListener: AnyCancellable?

  enum LoadState {
    case start
    case end
    case fail
  }

  init(
    configManager: ConfigManager
  ) {
    self.configManager = configManager
    Task {
      await listenForConfig()
    }
  }

  private func listenForConfig() {
    configListener = configManager.configState
      .compactMap { $0.getConfig() }
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] config in
          guard let self = self else {
            return
          }
          Task {
            await self.createSessions(from: config)
          }
        }
      )
  }

  // MARK: - Session Lifecycle

  /// Creates a session for each potential trigger on config and manual paywall presentation and sends them off to the server.
  func createSessions(from config: Config) async {
    // Loop through triggers and create a session for each.
    for trigger in config.triggers {
      // If an existing trigger exists, we don't want to
      // recreate the trigger session. This could happen if the
      // config is refreshed.
      if let activeTriggerSession = activeTriggerSession,
        activeTriggerSession.eventName == trigger.eventName {
        continue
      }
      let pendingTriggerSession = TriggerSession(eventName: trigger.eventName)
      pendingTriggerSessions[trigger.eventName] = pendingTriggerSession
    }
  }

  /// Active a pending trigger session.
  ///
  /// - Parameters:
  ///   - presentationInfo: Information about the paywall presentation.
  ///   - presentingViewController: What view the paywall will be presented on, if any.
  ///   - paywall: The response from the server associated with the paywall
  func activateSession(
    for presentationInfo: PresentationInfo,
    on presentingViewController: UIViewController? = nil,
    paywall: Paywall? = nil,
    triggerResult: InternalTriggerResult?,
    trackEvent: (Trackable) async -> TrackingResult = Superwall.shared.track
  ) async -> String? {
    guard let eventName = presentationInfo.eventName else {
      // The paywall is being presented by identifier, which is what the debugger uses,
      // and that's not supported.
      return nil
    }

    guard let session = pendingTriggerSessions[eventName] else {
      return nil
    }
    guard let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: presentationInfo,
      triggerResult: triggerResult?.toPublicType()
    ) else {
      return nil
    }

    self.activeTriggerSession = session
    pendingTriggerSessions[eventName] = nil

    if let triggerResult = triggerResult {
      let trackedEvent = InternalSuperwallEvent.TriggerFire(
        triggerResult: triggerResult,
        sessionId: session.id,
        triggerName: eventName
      )
      _ = await trackEvent(trackedEvent)
    }

    switch outcome {
    case .holdout,
      .noRuleMatch:
      await endSession()
    case .paywall:
      break
    }

    return session.id
  }

  /// Ends the active trigger session and resets it to `nil`.
  func endSession() async {
    guard let currentTriggerSession = activeTriggerSession else {
      return
    }

    // Recreate a pending trigger session
    let eventName = currentTriggerSession.eventName
    pendingTriggerSessions[eventName] = TriggerSession(eventName: eventName)

    // Reset state of current trigger session
    activeTriggerSession = nil
  }
}
