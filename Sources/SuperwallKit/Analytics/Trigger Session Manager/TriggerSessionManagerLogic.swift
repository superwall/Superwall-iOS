//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//
// swiftlint:disable function_body_length

import UIKit
import StoreKit

enum TriggerSessionManagerLogic {
  struct Outcome {
    let presentationOutcome: TriggerSession.PresentationOutcome
    let trigger: TriggerSession.Trigger
    let paywall: TriggerSession.Paywall?
  }

  static func outcome(
    presentationInfo: PresentationInfo,
    presentingViewController: UIViewController?,
    paywall: Paywall?,
    triggerResult: TriggerResult?
  ) -> Outcome? {
    let presentationOutcome: TriggerSession.PresentationOutcome
    let trigger: TriggerSession.Trigger
    var sessionPaywall: TriggerSession.Paywall?

    // Get the name of the presenting view controller
    var presentedOn: String?
    if let presentingViewController = presentingViewController {
      presentedOn = String(describing: type(of: presentingViewController))
    }

    // Is a Trigger
    switch presentationInfo {
    case let .implicitTrigger(eventData),
      let .explicitTrigger(eventData):
      guard let triggerResult = triggerResult else {
        return nil
      }
      switch triggerResult {
      case .error,
        .eventNotFound:
        // Error
        return nil
      case let .holdout(experiment):
        presentationOutcome = .holdout
        trigger = TriggerSession.Trigger(
          eventId: eventData.id,
          eventName: eventData.name,
          eventParameters: eventData.parameters,
          eventCreatedAt: eventData.createdAt,
          type: presentationInfo.triggerType,
          presentedOn: nil,
          experiment: experiment
        )
      case .noRuleMatch:
        presentationOutcome = .noRuleMatch
        trigger = TriggerSession.Trigger(
          eventId: eventData.id,
          eventName: eventData.name,
          eventParameters: eventData.parameters,
          eventCreatedAt: eventData.createdAt,
          type: presentationInfo.triggerType,
          presentedOn: nil
        )
      case let .paywall(experiment):
        presentationOutcome = .paywall
        trigger = TriggerSession.Trigger(
          eventId: eventData.id,
          eventName: eventData.name,
          eventParameters: eventData.parameters,
          eventCreatedAt: eventData.createdAt,
          type: presentationInfo.triggerType,
          presentedOn: presentedOn,
          experiment: experiment
        )
      }
    case .fromIdentifier:
      presentationOutcome = .paywall
      let eventData = EventData(
        name: "manual_present",
        parameters: [],
        createdAt: Date()
      )

      trigger = TriggerSession.Trigger(
        eventId: eventData.id,
        eventName: eventData.name,
        eventParameters: eventData.parameters,
        eventCreatedAt: eventData.createdAt,
        type: presentationInfo.triggerType,
        presentedOn: presentedOn
      )
    }

    if let paywall = paywall {
      sessionPaywall = TriggerSession.Paywall(
        databaseId: paywall.databaseId,
        substitutionPrefix: paywall.isFreeTrialAvailable ? "freeTrial" : nil,
        webviewLoading: paywall.webviewLoadingInfo,
        responseLoading: paywall.responseLoadingInfo
      )
    }

    return Outcome(
      presentationOutcome: presentationOutcome,
      trigger: trigger,
      paywall: sessionPaywall
    )
  }

  static func getTransactionOutcome(
    for product: StoreProduct,
    isFreeTrialAvailable: Bool
  ) -> TriggerSession.Transaction.Outcome {
    if product.subscriptionPeriod == nil {
      return .nonRecurringProductPurchase
    }

    if isFreeTrialAvailable {
      return .trialStart
    } else {
      return .subscriptionStart
    }
  }

  static func createPendingTriggerSession(
    configRequestId: String?,
    userAttributes: [String: Any],
    isSubscribed: Bool,
    eventName: String,
    products: [SWProduct] = [],
    appSession: AppSession
  ) -> TriggerSession {
    return TriggerSession(
      configRequestId: configRequestId ?? "",
      userAttributes: JSON(userAttributes),
      isSubscribed: isSubscribed,
      trigger: TriggerSession.Trigger(
        eventName: eventName
      ),
      products: TriggerSession.Products(
        allProducts: products
      ),
      appSession: appSession
    )
  }
}
