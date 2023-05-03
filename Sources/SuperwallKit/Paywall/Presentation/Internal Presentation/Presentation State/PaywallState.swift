//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/09/2022.
//

import Foundation

/// Contains the possible reasons for the dismissal of a paywall.
public enum PaywallResult: Equatable, Sendable {
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

/// Objective-C compatible enum for ``PaywallResult``
@objc(SWKPaywallResult)
public enum PaywallResultObjc: Int, Sendable {
  case purchased
  case closed
  case restored
}

/// The current state of a paywall.
public enum PaywallState {
  /// The paywall was presented. Contains a ``PaywallInfo`` object with more information about the presented paywall.
  case presented(PaywallInfo)

  /// A paywall may have been configured to show, but did not due to an `Error`.
  case presentationError(Error)

  /// The paywall was dismissed. Contains a ``PaywallInfo`` object with more information about the presented paywall and a ``PaywallResult`` object containing the paywall dismissal reason.
  case dismissed(PaywallInfo, PaywallResult)

  /// The paywall was intentionally skipped. Contains a ``PaywallSkippedReason`` enum whose cases state why the paywall was skipped.
  case skipped(PaywallSkippedReason)

}
