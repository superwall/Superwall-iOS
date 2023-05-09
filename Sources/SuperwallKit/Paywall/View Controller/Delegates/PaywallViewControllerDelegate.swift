//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/05/2023.
//

import Foundation

/// An interface for responding to user interactions with a ``PaywallViewController`` that
/// has been retrieved using
/// ``Superwall/getPaywallViewController(forEvent:params:paywallOverrides:delegate:)``.
public protocol PaywallViewControllerDelegate: AnyObject {
  /// Tells the delegate that the user finished interacting with the paywall.
  ///
  /// - Parameters:
  ///   - controller: The ``PaywallViewController`` that the user is interacting with.
  ///   - result: A ``PaywallResult`` enum that contains the reason for the dismissal of
  ///   the ``PaywallViewController``.
  @MainActor
  func paywallViewController(
    _ controller: PaywallViewController,
    didFinishWith result: PaywallResult
  )
}

/// Objective-C-only interface for responding to user interactions with a ``PaywallViewController`` that
/// has been retrieved using
/// ``Superwall/getPaywallViewController(forEvent:params:paywallOverrides:delegate:)``.
@objc(SWKPaywallViewControllerDelegate)
public protocol PaywallViewControllerDelegateObjc: AnyObject {
  /// Tells the delegate that the user finished interacting with the paywall.
  ///
  /// - Parameters:
  ///   - controller: The ``PaywallViewController`` that the user is interacting with.
  ///   - result: A ``PaywallResultObjc`` enum that contains the reason for the dismissal of
  ///   the ``PaywallViewController``.
  @MainActor
  @objc func paywallViewController(
    _ controller: PaywallViewController,
    didFinishWith result: PaywallResultObjc
  )
}

protocol PaywallViewControllerEventDelegate: AnyObject {
  @MainActor func eventDidOccur(
    _ paywallEvent: PaywallWebEvent,
    on paywallViewController: PaywallViewController
  ) async
}

enum PaywallLoadingState {
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
