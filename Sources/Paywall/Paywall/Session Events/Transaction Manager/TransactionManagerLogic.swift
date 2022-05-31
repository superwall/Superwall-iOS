//
//  File.swift
//  
//
//  Created by Yusuf Tör on 30/05/2022.
//

import Foundation
import StoreKit

enum TransactionManagerLogic {
  static func getTriggerSessionId(
    transaction: SKPaymentTransaction,
    activeTriggerSession: TriggerSession?
  ) -> String? {
    switch transaction.transactionState {
    case .purchasing,
      .restored:
      // Purchasing and restoration only happens via Superwall.
      // So we send back the trigger session id, if the session exists
      return activeTriggerSession?.id
    case .purchased,
        .deferred,
        .failed:
      // Only return the trigger session id if a transaction exists in the active session.
      // Otherwise these states may have occurred via renewal/purchasing outside of the app.
      // A purchased state with an active trigger session can only happen via a paywall, BUT the edge case is that a renewal comes in at the exact moment a user attempts to trigger a paywall.
      if activeTriggerSession?.transaction != nil {
        return activeTriggerSession?.id
      }
      return nil
    @unknown default:
      return nil
    }
  }
}
