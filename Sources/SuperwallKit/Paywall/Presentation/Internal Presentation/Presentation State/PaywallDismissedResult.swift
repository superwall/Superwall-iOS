//
//  PaywallDismissalResult.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation

/// Returned as a result of a paywall dismissing. It contains information about the paywall and the reason it was dismissed.
public struct PaywallDismissedResult {
  /// Contains information about the dismissed paywall
  public let paywallInfo: PaywallInfo

  /// Contains the possible reasons for the dismissal of a paywall.
  public enum DismissState: Equatable {
    /// The paywall was dismissed because the user purchased a product
    ///
    /// - Parameters:
    ///   - productId: The identifier of the product.
    case purchased(productId: String)

    /// The paywall was dismissed by the user manually pressing the close button.
    case closed

    /// The paywall was dismissed due to the user restoring their purchases.
    case restored
  }

  /// Contains information about why the paywall was dismissed.
  public let state: DismissState

  static func withResult(
    paywallInfo: PaywallInfo,
    state: DismissState
  ) -> Self {
    return PaywallDismissedResult(
      paywallInfo: paywallInfo,
      state: state
    )
  }
}

/// Objective-C compatible enum for `PaywallDismissedResult.DismissState`
@objc(SWKPaywallDismissedResultState)
public enum PaywallDismissedResultStateObjc: Int {
  case purchased
  case closed
  case restored
}
