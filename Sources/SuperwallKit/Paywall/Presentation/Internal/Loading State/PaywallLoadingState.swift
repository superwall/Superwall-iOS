//
//  PaywallLoadingState.swift
//  SuperwallKit
//
//  Created by Thomas LE GRAVIER on 03/10/2024.
//

import Foundation

/// Contains the possible loading states of a paywall.
@objc(SWKPaywallLoadingState)
public enum PaywallLoadingState: Int, Sendable {
  /// The initial state of the paywall
  case unknown

  /// When a purchase is loading
  case loadingPurchase

  /// When the paywall URL is loading
  case loadingURL

  /// When the user has manually shown the spinner
  case manualLoading

  /// When everything has loaded.
  case ready
}
