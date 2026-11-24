//
//  TransactionManager+TrackEvents.swift
//  SuperwallKit
//
//  Created by Superwall on 16/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

extension TransactionManager {
  /// Sends what the manager's real purchase and restore contexts track to
  /// `handler`, instead of to Superwall. A manager built with a fake context
  /// records an issue: read what was tracked from the fake instead.
  func trackEvents(
    with handler: @escaping (Trackable) async -> Void,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    guard
      let context = context as? AppTransactionContext,
      let restoreContext = restoreFlow.context as? AppRestoreContext
    else {
      Issue.record(
        "trackEvents needs a manager built with the real contexts",
        sourceLocation: sourceLocation
      )
      return
    }
    context.trackEvent = handler
    restoreContext.trackEvent = handler
  }
}
