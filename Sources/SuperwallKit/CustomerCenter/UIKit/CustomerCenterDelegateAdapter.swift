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
  @MainActor
  func makeCallbacks() -> CustomerCenterCallbacks {
    var callbacks = CustomerCenterCallbacks()
    let objcImplementsShouldRestore = (objcDelegate as? NSObjectProtocol)?.responds(
      to: #selector(CustomerCenterDelegateObjc.customerCenterShouldRestorePurchases(completion:))
    ) ?? false
    if swiftDelegate != nil || objcImplementsShouldRestore {
      callbacks.shouldRestore = { @MainActor [weak swiftDelegate, weak objcDelegate] in
        if let swiftDelegate {
          return await swiftDelegate.customerCenterShouldRestorePurchases()
        }
        guard let objcDelegate else { return true }
        return await withCheckedContinuation { continuation in
          let answer = FirstRestoreAnswer(continuation)
          if objcDelegate.customerCenterShouldRestorePurchases?(completion: answer.resume) == nil {
            answer.resume(true)
          }
        }
      }
    }
    callbacks.didSelectAction = { @MainActor [weak swiftDelegate, weak objcDelegate] action, pathId, purchase in
      swiftDelegate?.customerCenterDidSelectAction(action, pathId: pathId, purchase: purchase)
      objcDelegate?.customerCenterDidSelectAction?(CustomerCenterActionObjc(action), pathId: pathId, purchase: purchase)
    }
    callbacks.didCompleteSurvey = { @MainActor [weak swiftDelegate, weak objcDelegate] survey, option, action, path in
      swiftDelegate?.customerCenterDidCompleteSurvey(surveyId: survey, optionId: option, action: action, pathId: path)
      objcDelegate?.customerCenterDidCompleteSurvey?(
        surveyId: survey,
        optionId: option,
        action: CustomerCenterActionObjc(action),
        pathId: path
      )
    }
    callbacks.didCompleteRefund = { @MainActor [weak swiftDelegate, weak objcDelegate] productId, status in
      swiftDelegate?.customerCenterDidCompleteRefundRequest(productId: productId, status: status)
      objcDelegate?.customerCenterDidCompleteRefundRequest?(productId: productId, status: status)
    }
    callbacks.didDismiss = { @MainActor [weak swiftDelegate, weak objcDelegate] in
      swiftDelegate?.customerCenterDidDismiss()
      objcDelegate?.customerCenterDidDismiss?()
    }
    return callbacks
  }
}

/// Passes the first answer from an Objective-C restore completion to the waiting restore and
/// drops any later one. Resuming a continuation twice is a crash, and a host calling its
/// completion from two places shouldn't be able to take the app down.
final class FirstRestoreAnswer: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Bool, Never>?

  init(_ continuation: CheckedContinuation<Bool, Never>) {
    self.continuation = continuation
  }

  func resume(_ proceed: Bool) {
    lock.lock()
    let continuation = self.continuation
    self.continuation = nil
    lock.unlock()
    continuation?.resume(returning: proceed)
  }
}
