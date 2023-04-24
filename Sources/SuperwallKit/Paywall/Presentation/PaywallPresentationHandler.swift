//
//  File.swift
//  
//
//  Created by Jake Mor on 3/22/23.
//

import Foundation

/// The handler for ``Superwall/register(event:params:handler:feature:)`` whose functions
/// provide status updates for a paywall.
public class PaywallPresentationHandler: NSObject {
  /// A block called when the paywall did present.
  public var onPresent: ((_ paywallInfo: PaywallInfo) -> Void)?

  /// A block called when the paywall did dismiss.
  public var onDismiss: ((_ paywallInfo: PaywallInfo) -> Void)?

  /// A block called when an error occurred while trying to present a paywall.
  public var onError: ((_ error: Error) -> Void)?

  /// A convenience function to create a ``PaywallPresentationHandler`` that handles the
  /// ``PaywallPresentationHandler/onPresent`` case.
  public static func onPresent(_ onPresent: ((_ paywallInfo: PaywallInfo) -> Void)?) -> PaywallPresentationHandler {
    let handler = PaywallPresentationHandler()
    handler.onPresent = onPresent
    return handler
  }

  /// A convenience function to create a ``PaywallPresentationHandler`` that handles the
  /// ``PaywallPresentationHandler/onDismiss`` case.
  public static func onDismiss(_ onDismiss: ((_ paywallInfo: PaywallInfo) -> Void)?) -> PaywallPresentationHandler {
    let handler = PaywallPresentationHandler()
    handler.onDismiss = onDismiss
    return handler
  }

  /// A convenience function to create a ``PaywallPresentationHandler`` that handles the
  /// ``PaywallPresentationHandler/onError`` case.
  public static func onError(_ onError: ((_ error: Error) -> Void)?) -> PaywallPresentationHandler {
    let handler = PaywallPresentationHandler()
    handler.onError = onError
    return handler
  }
}
