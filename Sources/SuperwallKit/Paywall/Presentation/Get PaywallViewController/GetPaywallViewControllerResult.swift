//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/05/2023.
//

import Foundation

/// An object that represents the result of calling ``Superwall/getPaywallViewController(forEvent:params:paywallOverrides:completion:)-39418``.
@objc(SWKGetPaywallViewControllerResult)
@objcMembers
public final class GetPaywallViewControllerResult: NSObject {
  /// The ``PaywallViewController``.
  public let paywallViewController: PaywallViewController?

  /// The reason that the paywall retrieval was intentionally skipped.
  public let skippedReason: PaywallSkippedReasonObjc?

  /// Any errors that occurred when trying to retrieve the ``PaywallViewController``.
  public let error: Error?

  init(
    paywallViewController: PaywallViewController?,
    skippedReason: PaywallSkippedReasonObjc?,
    error: Error?
  ) {
    self.paywallViewController = paywallViewController
    self.skippedReason = skippedReason
    self.error = error
  }
}
