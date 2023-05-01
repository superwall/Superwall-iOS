//
//  File.swift
//  
//
//  Created by Jake Mor on 4/29/23.
//

import Foundation

/// An enum whose cases indicate whether the paywall was closed by user
/// interaction or for another paywall to show
@objc(SWKPaywallCloseReason)
public enum PaywallCloseReason: Int, Codable {
  case userInteraction

  /// Prevents the ``Superwall/register(event:params:handler:feature:)`` `feature`
  /// block from executing on dismiss of the paywall, because another paywall is set to show
  case forNextPaywall
}

