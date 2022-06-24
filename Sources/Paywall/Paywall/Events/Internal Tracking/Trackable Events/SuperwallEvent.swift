//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//
// swiftlint:disable:all nesting
// swiftlint:disable:all type_body_length

import Foundation
import StoreKit

protocol TrackableSuperwallEvent: Trackable {
  /// The Superwall ``Paywall/Paywall/EventName`` to be tracked by this event.
  var name: Paywall.EventName { get }
}

extension TrackableSuperwallEvent {
  var rawName: String {
    return name.rawValue
  }

  var canImplicitlyTriggerPaywall: Bool {
    return name.canImplicitlyTriggerPaywall
  }
}

/// These are events that tracked internally and sent back to the user via the delegate.
enum SuperwallEvent {
  struct AppOpen: TrackableSuperwallEvent {
    let name: Paywall.EventName = .appOpen
    var customParameters: [String: Any] = [:]
    var superwallParameters: [String: Any] = [:]
  }

  struct AppInstall: TrackableSuperwallEvent {
    let name: Paywall.EventName = .appInstall
    var customParameters: [String: Any] = [:]
    let superwallParameters: [String: Any] = [
      "application_installed_at": DeviceHelper.shared.appInstalledAtString
    ]
  }

  struct AppLaunch: TrackableSuperwallEvent {
    let name: Paywall.EventName = .appLaunch
    var customParameters: [String: Any] = [:]
    var superwallParameters: [String: Any] = [:]
  }

  struct FirstSeen: TrackableSuperwallEvent {
    let name: Paywall.EventName = .firstSeen
    var customParameters: [String: Any] = [:]
    var superwallParameters: [String: Any] = [:]
  }

  struct AppClose: TrackableSuperwallEvent {
    let name: Paywall.EventName = .appClose
    var customParameters: [String: Any] = [:]
    var superwallParameters: [String: Any] = [:]
  }

  struct SessionStart: TrackableSuperwallEvent {
    let name: Paywall.EventName = .sessionStart
    var customParameters: [String: Any] = [:]
    var superwallParameters: [String: Any] = [:]
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
    var customParameters: [String: Any] = [:]

    var superwallParameters: [String: Any] {
      let fromEvent = eventData != nil
      let params: [String: Any] = [
        "is_triggered_from_event": fromEvent,
        "event_name": eventData?.name ?? ""
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
    var customParameters: [String: Any] = [:]

    var superwallParameters: [String: Any] {
      switch triggerResult {
      case .noRuleMatch:
        return [
          "result": "no_rule_match",
          "trigger_name": triggerName
        ]
      case .holdout(let experiment):
        return [
          "variant_id": experiment.variant.id as Any,
          "experiment_id": experiment.id as Any,
          "result": "holdout",
          "trigger_name": triggerName
        ]
      case let .paywall(experiment):
        return [
          "variant_id": experiment.variant.id as Any,
          "experiment_id": experiment.id as Any,
          "paywall_identifier": experiment.variant.paywallId as Any,
          "result": "present",
          "trigger_name": triggerName
        ]
      case .unknownEvent:
        return [:]
      }
    }
  }

  struct PaywallOpen: TrackableSuperwallEvent {
    let name: Paywall.EventName = .paywallOpen
    let paywallInfo: PaywallInfo
    var superwallParameters: [String: Any] {
      return paywallInfo.eventParams()
    }
    var customParameters: [String: Any] = [:]
  }
  struct PaywallClose: TrackableSuperwallEvent {
    let name: Paywall.EventName = .paywallClose
    let paywallInfo: PaywallInfo
    var superwallParameters: [String: Any] {
      return paywallInfo.eventParams()
    }
    var customParameters: [String: Any] = [:]
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
    var customParameters: [String: Any] = [:]

    var superwallParameters: [String: Any] {
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
    var customParameters: [String: Any] = [:]

    var superwallParameters: [String: Any] {
      return paywallInfo.eventParams(forProduct: product)
    }
  }

  struct FreeTrialStart: TrackableSuperwallEvent {
    let name: Paywall.EventName = .freeTrialStart
    let paywallInfo: PaywallInfo
    let product: SKProduct
    var customParameters: [String: Any] = [:]

    var superwallParameters: [String: Any] {
      return paywallInfo.eventParams(forProduct: product)
    }
  }

  struct NonRecurringProductPurchase: TrackableSuperwallEvent {
    let name: Paywall.EventName = .nonRecurringProductPurchase
    let paywallInfo: PaywallInfo
    let product: SKProduct
    var customParameters: [String: Any] = [:]

    var superwallParameters: [String: Any] {
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

    var superwallParameters: [String: Any] {
      switch state {
      case .start,
        .fail,
        .complete:
        return paywallInfo.eventParams()
      }
    }
    var customParameters: [String: Any] = [:]
  }

  struct PaywallProductsLoad: TrackableSuperwallEvent {
    enum State {
      case start
      case fail
      case complete
    }
    let state: State
    var customParameters: [String: Any] = [:]

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

    var superwallParameters: [String: Any] {
      let fromEvent = eventData != nil
      let params: [String: Any] = [
        "is_triggered_from_event": fromEvent,
        "event_name": eventData?.name ?? ""
      ]

      switch state {
      case .start,
        .fail,
        .complete:
        return paywallInfo.eventParams(otherParams: params)
      }
    }
  }

  struct ManualPresent: TrackableSuperwallEvent {
    let name: Paywall.EventName = .manualPresent
    var customParameters: [String: Any] = [:]
    var superwallParameters: [String: Any] = [:]
  }
}
