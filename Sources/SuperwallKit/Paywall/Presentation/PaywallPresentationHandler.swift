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

//  init(onPresent: (@escaping (_: PaywallInfo) -> Void)? = nil, onDismiss: (@escaping (_: PaywallInfo) -> Void)? = nil, onError: (@escaping (_: Error) -> Void)? = nil) {
//    self.onPresent = onPresent
//    self.onDismiss = onDismiss
//    self.onError = onError
//  }

  public static func onPresent(_ onPresent: ((_ paywallInfo: PaywallInfo) -> Void)?) -> PaywallPresentationHandler {
    let h = PaywallPresentationHandler()
    h.onPresent = onPresent
    return h
  }

  public static func onDismiss(_ onDismiss: ((_ paywallInfo: PaywallInfo) -> Void)?) -> PaywallPresentationHandler {
    let h = PaywallPresentationHandler()
    h.onDismiss = onDismiss
    return h
  }

  public static func onError(_ onError: ((_ error: Error) -> Void)?) -> PaywallPresentationHandler {
    let h = PaywallPresentationHandler()
    h.onError = onError
    return h
  }
}
