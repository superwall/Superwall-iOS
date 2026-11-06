//
//  TestModeStatusSink.swift
//  SuperwallKit
//
//  Created by Superwall on 06/11/2026.
//

import Foundation

/// Where ``TestModeManager`` sends the subscription status and customer info
/// test mode keeps. Replaced in tests.
protocol TestModeStatusSink {
  @MainActor
  func send(customerInfo: CustomerInfo, status: SubscriptionStatus)

  /// Test mode turned off, so its entitlements must not stay as the status.
  @MainActor
  func sendTestModeEnded()
}

/// Sends test mode's status and customer info to `Superwall.shared`.
struct SuperwallTestModeStatusSink: TestModeStatusSink {
  /// An external purchase controller owns the status, and restores it itself
  /// once test mode turns off.
  var hasExternalPurchaseController: () -> Bool = { false }
  var grantedEntitlements: () -> Set<Entitlement> = { [] }

  @MainActor
  func send(customerInfo: CustomerInfo, status: SubscriptionStatus) {
    Superwall.shared.customerInfo = customerInfo
    Superwall.shared.setSubscriptionStatus(assigned: status)
  }

  @MainActor
  func sendTestModeEnded() {
    if hasExternalPurchaseController() {
      return
    }
    Superwall.shared.setSubscriptionStatus(assigned: .inactive)
    // Granted entitlements survive test mode, so the customer info has to
    // keep carrying them while the status does.
    Superwall.shared.customerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: []
    ).merging(with: .blank(), granting: grantedEntitlements())
  }
}
