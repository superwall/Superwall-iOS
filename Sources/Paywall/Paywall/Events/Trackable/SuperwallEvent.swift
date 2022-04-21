//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation
import StoreKit

protocol TrackableSuperwallEvent: Trackable {}

enum SuperwallEvent {
  struct AppOpen: TrackableSuperwallEvent {
    let name = Paywall.EventName.appOpen.rawValue
  }
  struct AppLaunch: TrackableSuperwallEvent {
    let name = Paywall.EventName.appLaunch.rawValue
  }
  struct FirstSeen: TrackableSuperwallEvent {
    let name = Paywall.EventName.firstSeen.rawValue
  }
  struct AppClose: TrackableSuperwallEvent {
    let name = Paywall.EventName.appClose.rawValue
  }
  struct SessionStart: TrackableSuperwallEvent {
    let name = Paywall.EventName.sessionStart.rawValue
  }

  struct PaywallResponseLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case notFound
      case fail
      case complete(paywallInfo: PaywallInfo)
    }
    let state: State

    var name: String {
      switch state {
      case .start:
        return Paywall.EventName.paywallResponseLoadStart.rawValue
      case .notFound:
        return Paywall.EventName.paywallResponseLoadNotFound.rawValue
      case .fail:
        return Paywall.EventName.paywallResponseLoadFail.rawValue
      case .complete:
        return Paywall.EventName.paywallResponseLoadComplete.rawValue
      }
    }
    let eventData: EventData?

    var parameters: [String : Any]? {
      let fromEvent = eventData != nil
      let params: [String: Any] = [
        "isTriggeredFromEvent": fromEvent,
        "eventName": eventData?.name ?? ""
      ]

      switch state {
      case .start,
        .notFound,
        .fail:
        return params
      case .complete(let paywallInfo):
        return paywallInfo.eventParams(otherParams: params)
      }
    }
  }

  struct TriggerFire: TrackableSuperwallEvent {
    let triggerResult: TriggerResult
    let name = Paywall.EventName.triggerFire.rawValue

    var parameters: [String : Any]? {
      switch triggerResult {
      case .noRuleMatch:
        return ["result": "no_rule_match"]
      case .holdout(let experiment):
        return [
          "variant_id": experiment.variantId as Any,
          "experiment_id": experiment.id as Any,
          "result": "holdout"
        ]
      case let .paywall(experiment, paywallIdentifier):
        return [
          "variant_id": experiment.variantId as Any,
          "experiment_id": experiment.id as Any,
          "paywall_identifier": paywallIdentifier,
          "result": "present"
        ]
      }
    }
  }

  struct PaywallOpen: TrackableSuperwallEvent {
    let name = Paywall.EventName.paywallOpen.rawValue
    let paywallInfo: PaywallInfo
    var parameters: [String : Any]? {
      return paywallInfo.eventParams()
    }
  }
  struct PaywallClose: TrackableSuperwallEvent {
    let name = Paywall.EventName.paywallClose.rawValue
    let paywallInfo: PaywallInfo
    var parameters: [String : Any]? {
      return paywallInfo.eventParams()
    }
  }

  struct Transaction: TrackableSuperwallEvent {
    enum State {
      case start
      case fail(message: String)
      case abandon
      case complete
      case restore
    }
    let state: State

    var name: String {
      switch state {
      case .start:
        return Paywall.EventName.transactionStart.rawValue
      case .fail:
        return Paywall.EventName.transactionFail.rawValue
      case .abandon:
        return Paywall.EventName.transactionAbandon.rawValue
      case .complete:
        return Paywall.EventName.transactionComplete.rawValue
      case .restore:
        return Paywall.EventName.transactionRestore.rawValue
      }
    }
    let paywallInfo: PaywallInfo
    let product: SKProduct?

    var parameters: [String : Any]? {
      switch state {
      case .start,
        .abandon,
        .complete,
        .restore:
        return paywallInfo.eventParams(forProduct: product)
      case .fail(let message):
        return paywallInfo.eventParams(
          forProduct: product,
          otherParams: ["message": message]
        )
      }
    }
  }

  struct SubscriptionStart: TrackableSuperwallEvent {
    let name = Paywall.EventName.subscriptionStart.rawValue
    let paywallInfo: PaywallInfo
    let product: SKProduct

    var parameters: [String : Any]? {
      return paywallInfo.eventParams(forProduct: product)
    }
  }

  struct FreeTrialStart: TrackableSuperwallEvent {
    let name = Paywall.EventName.freeTrialStart.rawValue
    let paywallInfo: PaywallInfo
    let product: SKProduct

    var parameters: [String : Any]? {
      return paywallInfo.eventParams(forProduct: product)
    }
  }

  struct NonRecurringProductPurchase: TrackableSuperwallEvent {
    let name = Paywall.EventName.nonRecurringProductPurchase.rawValue
    let paywallInfo: PaywallInfo
    let product: SKProduct

    var parameters: [String : Any]? {
      return paywallInfo.eventParams(forProduct: product)
    }
  }

  struct PaywallWebviewLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case fail
      case complete
    }
    let state: State

    var name: String {
      switch state {
      case .start:
        return Paywall.EventName.paywallWebviewLoadStart.rawValue
      case .fail:
        return Paywall.EventName.paywallWebviewLoadFail.rawValue
      case .complete:
        return Paywall.EventName.paywallWebviewLoadComplete.rawValue
      }
    }
    let paywallInfo: PaywallInfo

    var parameters: [String : Any]? {
      switch state {
      case .start,
        .fail,
        .complete:
        return paywallInfo.eventParams()
      }
    }
  }

  struct PaywallProductsLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case fail
      case complete
    }
    let state: State

    var name: String {
      switch state {
      case .start:
        return Paywall.EventName.paywallProductsLoadStart.rawValue
      case .fail:
        return Paywall.EventName.paywallProductsLoadFail.rawValue
      case .complete:
        return Paywall.EventName.paywallProductsLoadComplete.rawValue
      }
    }
    let paywallInfo: PaywallInfo
    let eventData: EventData?

    var parameters: [String : Any]? {
      let fromEvent = eventData != nil
      let params: [String: Any] = [
        "isTriggeredFromEvent": fromEvent,
        "eventName": eventData?.name ?? ""
      ]

      switch state {
      case .start,
        .fail,
        .complete:
        return paywallInfo.eventParams(otherParams: params)
      }
    }
  }
}
