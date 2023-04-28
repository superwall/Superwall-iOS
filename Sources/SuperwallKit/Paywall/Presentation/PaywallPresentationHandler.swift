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
  public var onPresent: ((_ paywallInfo: PaywallInfo) -> Void)?

  /// A block called when the paywall did dismiss.
  public var onDismiss: ((_ paywallInfo: PaywallInfo) -> Void)?

  /// A block called when an error occurred while trying to present a paywall.
  public var onError: ((_ error: Error) -> Void)?
}
