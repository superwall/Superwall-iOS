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
  /// Tells the delegate to handle the dismissal of the paywall.
  ///
  /// - Parameters:
  ///   - paywall: The ``PaywallViewController`` that the user is interacting with.
  ///   - result: A ``PaywallResult`` enum that contains the reason for the dismissal of
  ///   the ``PaywallViewController``.
  @MainActor
  func handle(
    paywall: PaywallViewController,
    result: PaywallResult
  )

  /// Tells the delegate that the paywall disappeared.
  ///
  /// - Parameters:
  ///   - paywall: The ``PaywallViewController`` that the user is interacting with.
  ///   - result: A ``PaywallResult`` enum that contains the reason for the disappearing of
  ///   the ``PaywallViewController``.
  @MainActor
  func paywall(
    _ paywall: PaywallViewController,
    didDisappearWith result: PaywallResult
  )
}

public extension PaywallViewControllerDelegate {
  func paywall(
    _ paywall: PaywallViewController,
    didDisappearWith result: PaywallResult
  ) {}
}

/// Objective-C-only interface for responding to user interactions with a ``PaywallViewController`` that
/// has been retrieved using
/// ``Superwall/getPaywallViewController(forEvent:params:paywallOverrides:delegate:)``.
@objc(SWKPaywallViewControllerDelegate)
public protocol PaywallViewControllerDelegateObjc: AnyObject {
  /// Tells the delegate to handle the dismissal of the paywall.
  ///
  /// - Parameters:
  ///   - paywall: The ``PaywallViewController`` that the user is interacting with.
  ///   - result: A ``PaywallResultObjc`` enum that contains the reason for the dismissal of
  ///   the ``PaywallViewController``.
  @MainActor
  @objc func handle(
    paywall: PaywallViewController,
    result: PaywallResultObjc
  )

  /// Tells the delegate that the paywall disappeared.
  ///
  /// - Parameters:
  ///   - paywall: The ``PaywallViewController`` that the user is interacting with.
  ///   - result: A ``PaywallResult`` enum that contains the reason for the disappearing of
  ///   the ``PaywallViewController``.
  @MainActor
  @objc optional func paywall(
    _ paywall: PaywallViewController,
    didDisappearWithResult result: PaywallResultObjc
  )
}

public extension PaywallViewControllerDelegateObjc {
  func paywall(
    _ paywall: PaywallViewController,
    didDisappearWithResult result: PaywallResultObjc
  ) {}
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
