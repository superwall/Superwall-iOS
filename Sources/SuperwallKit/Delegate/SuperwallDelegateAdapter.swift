//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/10/2022.
//

import Foundation
import Combine
import StoreKit

/// An adapter between the internal SDK and the public swift/objective c delegate.
final class SuperwallDelegateAdapter {
  var swiftDelegate: SuperwallDelegate?
  var objcDelegate: SuperwallDelegateObjc?

  @MainActor
  func handleCustomPaywallAction(withName name: String) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.handleCustomPaywallAction(withName: name)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.handleCustomPaywallAction?(withName: name)
    }
  }

  @MainActor
  func willDismissPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willDismissPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willDismissPaywall?(withInfo: paywallInfo)
    }
  }

  @MainActor
  func willPresentPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willPresentPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willPresentPaywall?(withInfo: paywallInfo)
    }
  }

  @MainActor
  func didDismissPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didDismissPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didDismissPaywall?(withInfo: paywallInfo)
    }
  }

  @MainActor
  func didPresentPaywall(withInfo paywallInfo: PaywallInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didPresentPaywall(withInfo: paywallInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didPresentPaywall?(withInfo: paywallInfo)
    }
  }

  @MainActor
  func paywallWillOpenURL(url: URL) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.paywallWillOpenURL(url: url)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.paywallWillOpenURL?(url: url)
    }
  }

  @MainActor
  func paywallWillOpenDeepLink(url: URL) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.paywallWillOpenDeepLink(url: url)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.paywallWillOpenDeepLink?(url: url)
    }
  }

  @MainActor
  func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.handleSuperwallPlacement(withInfo: eventInfo)
      swiftDelegate.handleSuperwallEvent(withInfo: eventInfo)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.handleSuperwallPlacement?(withInfo: eventInfo)
      objcDelegate.handleSuperwallEvent?(withInfo: eventInfo)
    }
  }

  @MainActor
  func subscriptionStatusDidChange(
    from oldValue: SubscriptionStatus,
    to newValue: SubscriptionStatus
  ) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.subscriptionStatusDidChange(
        from: oldValue,
        to: newValue
      )
    } else if let objcDelegate = objcDelegate {
      objcDelegate.subscriptionStatusDidChange?(
        from: oldValue.toObjc(),
        to: newValue.toObjc()
      )
    }
  }

  @MainActor
  func handleLog(
    level: String,
    scope: String,
    message: String?,
    info: [String: Any]?,
    error: Swift.Error?
  ) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.handleLog(
        level: level,
        scope: scope,
        message: message,
        info: info,
        error: error
      )
    } else if let objcDelegate = objcDelegate {
      objcDelegate.handleLog?(
        level: level,
        scope: scope,
        message: message,
        info: info,
        error: error
      )
    }
  }

  @MainActor
  func didRedeemCode(result: RedemptionResult) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didRedeemCode(result: result)
    }
    // TODO: Objective C version
  }

  @MainActor
  func willRedeemCode() {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willRedeemCode()
    }
    // TODO: Objective C version
  }
}
