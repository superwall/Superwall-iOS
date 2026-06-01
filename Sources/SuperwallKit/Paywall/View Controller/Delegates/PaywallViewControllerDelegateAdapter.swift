//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/05/2023.
//

import Foundation

/// An adapter between the internal SDK and the public swift/objective c ``PaywallViewController`` delegate.
final class PaywallViewControllerDelegateAdapter {
  weak var swiftDelegate: PaywallViewControllerDelegate?
  weak var objcDelegate: PaywallViewControllerDelegateObjc?

  /// An optional handler invoked when the paywall webview triggers a custom callback.
  let onCustomCallback: ((CustomCallback) async -> CustomCallbackResult)?

  var hasObjcDelegate: Bool {
    return objcDelegate != nil
  }

  init(
    swiftDelegate: PaywallViewControllerDelegate?,
    objcDelegate: PaywallViewControllerDelegateObjc?,
    onCustomCallback: ((CustomCallback) async -> CustomCallbackResult)? = nil
  ) {
    self.swiftDelegate = swiftDelegate
    self.objcDelegate = objcDelegate
    self.onCustomCallback = onCustomCallback
  }

  @MainActor
  func didFinish(
    paywall: PaywallViewController,
    result: PaywallResult,
    shouldDismiss: Bool
  ) {
    swiftDelegate?.paywall(paywall, didFinishWith: result, shouldDismiss: shouldDismiss)
    objcDelegate?.paywall(paywall, didFinishWithResult: result.convertForObjc(), shouldDismiss: shouldDismiss)
  }

  @MainActor
  func loadingStateDidChange(
    paywall: PaywallViewController,
    loadingState: PaywallLoadingState
  ) {
    swiftDelegate?.paywall(paywall, loadingStateDidChange: loadingState)
    objcDelegate?.paywall(paywall, loadingStateDidChange: loadingState)
  }
}

// MARK: - Stubbable
extension PaywallViewControllerDelegateAdapter: Stubbable {
  static func stub() -> PaywallViewControllerDelegateAdapter {
    return PaywallViewControllerDelegateAdapter(
      swiftDelegate: nil,
      objcDelegate: nil
    )
  }
}
