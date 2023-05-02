//
//  File.swift
//  
//
//  Created by Jake Mor on 3/22/23.
//

import Foundation

/// The handler for ``Superwall/register(event:params:handler:feature:)`` whose
/// variables provide status updates for a paywall.
@objc(SWKPaywallPresentationHandler)
@objcMembers
public class PaywallPresentationHandler: NSObject {
  /// A block called when the paywall did present.
  var onPresentHandler: ((_ paywallInfo: PaywallInfo) -> Void)?

  /// A block called when the paywall did dismiss.
  var onDismissHandler: ((_ paywallInfo: PaywallInfo) -> Void)?

  /// A block called when an error occurred while trying to present a paywall.
  var onErrorHandler: ((_ error: Error) -> Void)?

  /// Sets the handler that will be called when the paywall did presented.
  ///
  /// - Parameter handler: A block that accepts a ``PaywallInfo`` object associated with
  /// the presented paywall.
  public func onPresent(_ handler: @escaping (_ paywallInfo: PaywallInfo) -> Void) {
    self.onPresentHandler = handler
  }

  /// Sets the handler that will be called when the paywall did dismissed.
  ///
  /// - Parameter handler: A block that accepts a ``PaywallInfo`` object associated with
  /// the dismissed paywall.
  public func onDismiss(_ handler: @escaping (_ paywallInfo: PaywallInfo) -> Void) {
    self.onDismissHandler = handler
  }

  /// Sets the handler that will be called when an error occurred while trying to present a paywall.
  ///
  /// - Parameter handler: A block that accepts an `Error` indicating why the paywall
  /// could not present.
  public func onError(_ handler: @escaping (_ error: Error) -> Void) {
    self.onErrorHandler = handler
  }
}
