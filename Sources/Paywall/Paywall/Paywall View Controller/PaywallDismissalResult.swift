//
//  PaywallDismissalResult.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation

struct PaywallDismissalResult {
  let paywallInfo: PaywallInfo?
  enum DismissState {
    case purchased(productId: String)
    case closed
    case restored
  }
  let state: DismissState

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
