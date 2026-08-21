//
//  CustomerCenterDelegateAdapter.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

/// An adapter between the internal SDK and the public swift/objective-c ``CustomerCenterDelegate``.
@available(iOS 15.0, *)
struct CustomerCenterDelegateAdapter {
  // Weak so the view controller never retains its delegate — a host that both presents the
  // Customer Center and is its own delegate would otherwise cycle with the VC/view model that
  // holds these callbacks. Callers that create a delegate inline must keep their own strong
  // reference; `Superwall.shared.presentCustomerCenter(delegate:)` is expected to provide that
  // strong retention for the duration of the presentation.
  weak var swiftDelegate: CustomerCenterDelegate?
  weak var objcDelegate: CustomerCenterDelegateObjc?

  /// Builds the callbacks the view model uses to notify the delegate.
  ///
  /// `shouldRestore` is left `nil` unless a Swift delegate is set or the ObjC delegate implements
  /// the optional method, so the view model's default (proceed) behavior applies when there's
  /// nothing to gate on.
  func makeCallbacks() -> CustomerCenterCallbacks {
    var callbacks = CustomerCenterCallbacks()
    let objcImplementsShouldRestore = (objcDelegate as? NSObjectProtocol)?.responds(
      to: #selector(CustomerCenterDelegateObjc.customerCenter(shouldRestorePurchases:))
    ) ?? false
    if swiftDelegate != nil || objcImplementsShouldRestore {
      callbacks.shouldRestore = { [weak swiftDelegate, weak objcDelegate] resume in
        if let swiftDelegate {
          swiftDelegate.customerCenter(shouldRestorePurchases: resume)
        } else if let objcDelegate {
          objcDelegate.customerCenter?(shouldRestorePurchases: resume)
        } else {
          resume(true)
        }
      }
    }
    callbacks.didSelectAction = { [weak swiftDelegate, weak objcDelegate] action, purchase in
      swiftDelegate?.customerCenter(didSelect: action, for: purchase)
      objcDelegate?.customerCenter?(didSelect: CustomerCenterActionObjc(action), for: purchase)
    }
    callbacks.didCompleteSurvey = { [weak swiftDelegate, weak objcDelegate] surveyId, optionId, action in
      swiftDelegate?.customerCenter(didCompleteSurvey: surveyId, optionId: optionId, for: action)
      objcDelegate?.customerCenter?(
        didCompleteSurvey: surveyId,
        optionId: optionId,
        for: CustomerCenterActionObjc(action)
      )
    }
    callbacks.didCompleteRefund = { [weak swiftDelegate, weak objcDelegate] productId, status in
      swiftDelegate?.customerCenter(didCompleteRefundRequestFor: productId, status: status)
      objcDelegate?.customerCenter?(didCompleteRefundRequestFor: productId, status: status)
    }
    callbacks.didDismiss = { [weak swiftDelegate, weak objcDelegate] in
      swiftDelegate?.customerCenterDidDismiss()
      objcDelegate?.customerCenterDidDismiss?()
    }
    return callbacks
  }
}
