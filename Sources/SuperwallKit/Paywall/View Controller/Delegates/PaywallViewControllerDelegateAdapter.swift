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

  var hasObjcDelegate: Bool {
    return objcDelegate != nil
  }

  init(
    swiftDelegate: PaywallViewControllerDelegate?,
    objcDelegate: PaywallViewControllerDelegateObjc?
  ) {
    self.swiftDelegate = swiftDelegate
    self.objcDelegate = objcDelegate
  }

  @MainActor
  func didFinish(
    controller: PaywallViewController,
    swiftResult: PaywallResult,
    objcResult: PaywallResultObjc
  ) {
    swiftDelegate?.paywallViewController(controller, didFinishWith: swiftResult)
    objcDelegate?.paywallViewController(controller, didFinishWith: objcResult)
  }
}

extension PaywallViewControllerDelegateAdapter: Stubbable {
  static func stub() -> PaywallViewControllerDelegateAdapter {
    return PaywallViewControllerDelegateAdapter(
      swiftDelegate: nil,
      objcDelegate: nil
    )
  }
}
