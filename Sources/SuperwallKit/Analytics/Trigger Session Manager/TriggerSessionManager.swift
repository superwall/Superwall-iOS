//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//
// swiftlint:disable type_body_length file_length

import UIKit
import StoreKit
import Combine

actor TriggerSessionManager {
  /// The list of all potential trigger sessions, keyed by the trigger event name, created after receiving the config.
  private var pendingTriggerSessions: [String: TriggerSession] = [:]

  /// The active trigger session.
  var activeTriggerSession: TriggerSession?

  private unowned let configManager: ConfigManager
  private unowned let appSessionManager: AppSessionManager
  private unowned let identityManager: IdentityManager

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
    configManager: ConfigManager,
    appSessionManager: AppSessionManager,
    identityManager: IdentityManager
  ) {
    self.configManager = configManager
    self.appSessionManager = appSessionManager
    self.identityManager = identityManager
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
    let isUserSubscribed = Superwall.shared.subscriptionStatus == .active
    for trigger in config.triggers {
      // If an existing trigger exists, we don't want to
      // recreate the trigger session. This could happen if the
      // config is refreshed.
      if let activeTriggerSession = activeTriggerSession,
         activeTriggerSession.trigger.eventName == trigger.eventName {
        continue
      }
      let pendingTriggerSession = TriggerSessionManagerLogic.createPendingTriggerSession(
        configRequestId: configManager.config?.requestId,
        userAttributes: identityManager.userAttributes,
        isSubscribed: isUserSubscribed,
        eventName: trigger.eventName,
        appSession: appSessionManager.appSession
      )
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

    guard var session = pendingTriggerSessions[eventName] else {
      return nil
    }
    guard let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: presentationInfo,
      presentingViewController: presentingViewController,
      paywall: paywall,
      triggerResult: triggerResult?.toPublicType()
    ) else {
      return nil
    }

    // Update trigger session
    session.userAttributes = JSON(identityManager.userAttributes)
    session.presentationOutcome = outcome.presentationOutcome
    session.trigger = outcome.trigger
    session.paywall = outcome.paywall
    session.products = TriggerSession.Products(
      allProducts: paywall?.swProducts ?? [],
      loadingInfo: paywall?.productsLoadingInfo
    )

    session.appSession = appSessionManager.appSession

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

    switch outcome.presentationOutcome {
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
    guard var currentTriggerSession = activeTriggerSession else {
      return
    }

    // Recreate a pending trigger session
    let eventName = currentTriggerSession.trigger.eventName
    let isUserSubscribed = Superwall.shared.subscriptionStatus == .active
    let pendingTriggerSession = TriggerSessionManagerLogic.createPendingTriggerSession(
      configRequestId: configManager.config?.requestId,
      userAttributes: identityManager.userAttributes,
      isSubscribed: isUserSubscribed,
      eventName: eventName,
      products: currentTriggerSession.products.allProducts,
      appSession: appSessionManager.appSession
    )
    pendingTriggerSessions[eventName] = pendingTriggerSession

    // Reset state of current trigger session
    activeTriggerSession = nil
  }
}
