//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 14/03/2025.
//

import Foundation

/// Info about the customer such as active entitlements and redeemed codes.
public struct CustomerInfo {
  /// The active entitlements.
  public let entitlements: [Entitlement]

  /// An `Array` of ``RedemptionResult`` objects, representing all the results of
  /// codes that were redeemed.
  public let redemptions: [RedemptionResult]
}
