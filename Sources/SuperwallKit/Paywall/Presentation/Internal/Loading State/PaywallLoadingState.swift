//
//  PaywallLoadingState.swift
//  SuperwallKit
//
//  Created by Thomas LE GRAVIER on 03/10/2024.
//

import Foundation

/// Contains the possible loading state of a paywall.
public enum PaywallLoadingState {
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

  func convertForObjc() -> PaywallLoadingStateObjc {
    switch self {
    case .unknown:
      return .unknown
    case .loadingPurchase:
      return .loadingPurchase
    case .loadingURL:
      return .loadingURL
    case .manualLoading:
      return .manualLoading
    case .ready:
      return .ready
    }
  }
}

/// Objective-C-only enum. Contains the possible loading state of a paywall.
@objc(SWKPaywallLoadingState)
public enum PaywallLoadingStateObjc: Int, Sendable {
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
