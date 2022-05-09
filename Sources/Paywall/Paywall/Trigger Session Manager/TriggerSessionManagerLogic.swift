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
    paywallResponse: PaywallResponse?
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
      let outcome = TriggerManager.handleEvent(eventData)
      switch outcome {
      case .unknownEvent:
        // Error
        return nil
      case let .holdout(groupId, experimentId, variantId):
        presentationOutcome = .holdout
        trigger = TriggerSession.Trigger(
          eventData: eventData,
          type: presentationInfo.triggerType,
          presentedOn: nil,
          experiment: TriggerSession.Trigger.Experiment(
            id: experimentId,
            groupId: groupId,
            variant: TriggerSession.Trigger.Experiment.Variant(
              id: variantId,
              type: .holdout
            )
          )
        )
      case .noRuleMatch:
        presentationOutcome = .noRuleMatch
        trigger = TriggerSession.Trigger(
          eventData: eventData,
          type: presentationInfo.triggerType,
          presentedOn: nil
        )
      case let .presentV2(groupId, experimentId, variantId, _):
        presentationOutcome = .paywall
        trigger = TriggerSession.Trigger(
          eventData: eventData,
          type: presentationInfo.triggerType,
          presentedOn: presentedOn,
          experiment: TriggerSession.Trigger.Experiment(
            id: experimentId,
            groupId: groupId,
            variant: TriggerSession.Trigger.Experiment.Variant(
              id: variantId,
              type: .treatment
            )
          )
        )
      }
    case .fromIdentifier,
      .defaultPaywall:
      presentationOutcome = .paywall
      let eventData = Paywall.track(SuperwallEvent.ManualPresent()).data
      trigger = TriggerSession.Trigger(
        eventData: eventData,
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
}
