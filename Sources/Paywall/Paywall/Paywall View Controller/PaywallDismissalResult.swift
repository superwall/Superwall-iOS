//
//  PaywallDismissalResult.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation

public struct PaywallDismissalResult {
  public let paywallInfo: PaywallInfo?
  public enum DismissState {
    case purchased(productId: String)
    case closed
    case restored
  }
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
