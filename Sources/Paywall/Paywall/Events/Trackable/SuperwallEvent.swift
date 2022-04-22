//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation
import StoreKit

protocol TrackableSuperwallEvent: Trackable {
  var name: Paywall.EventName { get }
}

extension TrackableSuperwallEvent {
  var rawName: String {
    return name.rawValue
  }
}

enum SuperwallEvent {
  struct AppOpen: TrackableSuperwallEvent {
    let name: Paywall.EventName = .appOpen
  }
  struct AppLaunch: TrackableSuperwallEvent {
    let name: Paywall.EventName = .appLaunch
  }
  struct FirstSeen: TrackableSuperwallEvent {
    let name: Paywall.EventName = .firstSeen
  }
  struct AppClose: TrackableSuperwallEvent {
    let name: Paywall.EventName = .appClose
  }
  struct SessionStart: TrackableSuperwallEvent {
    let name: Paywall.EventName = .sessionStart
  }

  struct PaywallResponseLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case notFound
      case fail
      case complete(paywallInfo: PaywallInfo)
    }
    let state: State

    var name: Paywall.EventName {
      switch state {
      case .start:
        return .paywallResponseLoadStart
      case .notFound:
        return .paywallResponseLoadNotFound
      case .fail:
        return .paywallResponseLoadFail
      case .complete:
        return .paywallResponseLoadComplete
      }
    }
    let eventData: EventData?

    var superwallParameters: [String : Any]? {
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
    let name: Paywall.EventName = .triggerFire
    let triggerName: String

    var superwallParameters: [String : Any]? {
      switch triggerResult {
      case .noRuleMatch:
        return [
          "result": "no_rule_match",
          "trigger_name": triggerName
        ]
      case .holdout(let experiment):
        return [
          "variant_id": experiment.variantId as Any,
          "experiment_id": experiment.id as Any,
          "result": "holdout",
          "trigger_name": triggerName
        ]
      case let .paywall(experiment, paywallIdentifier):
        return [
          "variant_id": experiment.variantId as Any,
          "experiment_id": experiment.id as Any,
          "paywall_identifier": paywallIdentifier,
          "result": "present",
          "trigger_name": triggerName
        ]
      }
    }
  }

  struct PaywallOpen: TrackableSuperwallEvent {
    let name: Paywall.EventName = .paywallOpen
    let paywallInfo: PaywallInfo
    var superwallParameters: [String : Any]? {
      return paywallInfo.eventParams()
    }
  }
  struct PaywallClose: TrackableSuperwallEvent {
    let name: Paywall.EventName = .paywallClose
    let paywallInfo: PaywallInfo
    var superwallParameters: [String : Any]? {
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

    var name: Paywall.EventName {
      switch state {
      case .start:
        return .transactionStart
      case .fail:
        return .transactionFail
      case .abandon:
        return .transactionAbandon
      case .complete:
        return .transactionComplete
      case .restore:
        return .transactionRestore
      }
    }
    let paywallInfo: PaywallInfo
    let product: SKProduct?

    var superwallParameters: [String : Any]? {
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
    let name: Paywall.EventName = .subscriptionStart
    let paywallInfo: PaywallInfo
    let product: SKProduct

    var superwallParameters: [String : Any]? {
      return paywallInfo.eventParams(forProduct: product)
    }
  }

  struct FreeTrialStart: TrackableSuperwallEvent {
    let name: Paywall.EventName = .freeTrialStart
    let paywallInfo: PaywallInfo
    let product: SKProduct

    var superwallParameters: [String : Any]? {
      return paywallInfo.eventParams(forProduct: product)
    }
  }

  struct NonRecurringProductPurchase: TrackableSuperwallEvent {
    let name: Paywall.EventName = .nonRecurringProductPurchase
    let paywallInfo: PaywallInfo
    let product: SKProduct

    var superwallParameters: [String : Any]? {
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

    var name: Paywall.EventName {
      switch state {
      case .start:
        return .paywallWebviewLoadStart
      case .fail:
        return .paywallWebviewLoadFail
      case .complete:
        return .paywallWebviewLoadComplete
      }
    }
    let paywallInfo: PaywallInfo

    var superwallParameters: [String : Any]? {
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

    var name: Paywall.EventName {
      switch state {
      case .start:
        return .paywallProductsLoadStart
      case .fail:
        return .paywallProductsLoadFail
      case .complete:
        return .paywallProductsLoadComplete
      }
    }
    let paywallInfo: PaywallInfo
    let eventData: EventData?

    var superwallParameters: [String : Any]? {
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
