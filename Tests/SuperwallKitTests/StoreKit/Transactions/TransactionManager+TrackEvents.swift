//
//  TransactionManager+TrackEvents.swift
//  SuperwallKit
//
//  Created by Superwall on 16/11/2026.
//
// swiftlint:disable all

import Foundation
@testable import SuperwallKit

extension TransactionManager {
  /// Sends what the manager's real purchase and restore contexts track to
  /// `handler`, instead of to Superwall.
  func trackEvents(with handler: @escaping (Trackable) async -> Void) {
    (context as? AppTransactionContext)?.trackEvent = handler
    (restoreFlow.context as? AppRestoreContext)?.trackEvent = handler
  }
}
