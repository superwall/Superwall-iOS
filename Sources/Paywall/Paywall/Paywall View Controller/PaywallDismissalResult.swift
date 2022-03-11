//
//  PaywallDismissalResult.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation

public struct PaywallDismissalResult {
  /// Contains information about the paywall
  public let paywallInfo: PaywallInfo?

  public enum DismissState {
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
    paywallInfo: PaywallInfo?,
    state: DismissState
  ) -> Self {
    return PaywallDismissalResult(
      paywallInfo: paywallInfo,
      state: state
    )
  }
}
