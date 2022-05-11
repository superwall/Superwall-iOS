//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//

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
    paywallResponse: PaywallResponse?,
    triggers: [String: Trigger] = Storage.shared.triggers
  ) -> Outcome? {
    let presentationOutcome: TriggerSession.PresentationOutcome
    let trigger: TriggerSession.Trigger
    var paywall: TriggerSession.Paywall?

    // Get the name of the presenting view controller
    var presentedOn: String?
    if let presentingViewController = presentingViewController {
      presentedOn = String(describing: type(of: presentingViewController))
    }

    // Is a Trigger
    switch presentationInfo {
    case let .implicitTrigger(eventData),
      let .explicitTrigger(eventData):
      
      let outcome = TriggerLogic.outcome(
        forEvent: eventData,
        triggers: triggers
      ).result
      switch outcome {
      case .unknownEvent:
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
          experiment: Experiment(
            id: experiment.id,
            groupId: experiment.groupId,
            variant: Experiment.Variant(
              id: experiment.variant.id,
              type: .holdout,
              paywallId: nil
            )
          )
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
          experiment: Experiment(
            id: experiment.id,
            groupId: experiment.groupId,
            variant: Experiment.Variant(
              id: experiment.variant.id,
              type: .treatment,
              paywallId: nil
            )
          )
        )
      }
    case .fromIdentifier,
      .defaultPaywall:
      presentationOutcome = .paywall
      let eventData = Paywall.track(SuperwallEvent.ManualPresent()).data
      trigger = TriggerSession.Trigger(
        eventId: eventData.id,
        eventName: eventData.name,
        eventParameters: eventData.parameters,
        eventCreatedAt: eventData.createdAt,
        type: presentationInfo.triggerType,
        presentedOn: presentedOn
      )
    }

    if let paywallResponse = paywallResponse {
      let paywallInfo = paywallResponse.getPaywallInfo(fromEvent: presentationInfo.eventData)

      paywall = TriggerSession.Paywall(
        databaseId: paywallInfo.id,
        substitutionPrefix: paywallResponse.templateSubstitutionsPrefix.prefix,
        webViewLoading: .init(
          startAt: paywallResponse.webViewLoadStartTime,
          endAt: paywallResponse.webViewLoadCompleteTime,
          failAt: paywallResponse.webViewLoadFailTime
        ),
        responseLoading: .init(
          startAt: paywallResponse.responseLoadStartTime,
          endAt: paywallResponse.responseLoadCompleteTime,
          failAt: paywallResponse.responseLoadFailTime
        )
      )
    }

    return Outcome(
      presentationOutcome: presentationOutcome,
      trigger: trigger,
      paywall: paywall
    )
  }

  static func getTransactionOutcome(
    for product: SKProduct,
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
    configRequestId: String,
    userAttributes: [String: Any],
    isSubscribed: Bool,
    eventName: String,
    products: [SWProduct],
    appSession: AppSession
  ) -> TriggerSession {
    return TriggerSession(
      configRequestId: configRequestId,
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
