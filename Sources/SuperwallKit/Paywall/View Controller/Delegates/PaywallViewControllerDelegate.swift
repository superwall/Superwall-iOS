//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/05/2023.
//

import Foundation

/// An interface for responding to user interactions with a ``PaywallViewController`` that
/// has been retrieved using
/// ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:)``.
public protocol PaywallViewControllerDelegate: AnyObject {
  /// Tells the delegate that the user finished interacting with the paywall and whether the delegate
  /// should dismiss the paywall.
  ///
  /// You should always check the `shouldDismiss` parameter to decide what to do when this method
  /// is called. If `shouldDismiss` is `true`, make sure to dismiss the paywall.
  ///
  /// - Parameters:
  ///   - paywall: The ``PaywallViewController`` that the user is interacting with.
  ///   - result: A ``PaywallResult`` enum that contains the reason for the dismissal of
  ///   the ``PaywallViewController``.
  ///   - shouldDismiss: A `boolean` indicating whether the delegate should dismiss the paywall.
  @MainActor
  func paywall(
    _ paywall: PaywallViewController,
    didFinishWith result: PaywallResult,
    shouldDismiss: Bool
  )
}

/// Objective-C-only interface for responding to user interactions with a ``PaywallViewController`` that
/// has been retrieved using
/// ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:completion:)-5vtpb``.
@objc(SWKPaywallViewControllerDelegate)
public protocol PaywallViewControllerDelegateObjc: AnyObject {
  /// Tells the delegate that the user finished interacting with the paywall and whether the delegate
  /// should dismiss the paywall.
  ///
  /// You should always check the `shouldDismiss` parameter to decide what to do when this method
  /// is called. If `shouldDismiss` is `true`, make sure to dismiss the paywall.
  ///
  /// - Parameters:
  ///   - paywall: The ``PaywallViewController`` that the user is interacting with.
  ///   - result: A ``PaywallResultObjc`` enum that contains the reason for the dismissal of
  ///   the ``PaywallViewController``.
  ///   - shouldDismiss: A `boolean` indicating whether the delegate should dismiss the paywall.
  @MainActor
  func paywall(
    _ paywall: PaywallViewController,
    didFinishWithResult result: PaywallResultObjc,
    shouldDismiss: Bool
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
