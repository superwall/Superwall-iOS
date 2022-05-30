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
      return activeTriggerSession?.id
    case .purchased,
        .deferred,
        .failed:
      // Only return trigger session id if a transaction exists in the active session.
      // Otherwise these states may have occurred via renewal/purchasing outside of the app.
      if activeTriggerSession?.transaction != nil {
        return activeTriggerSession?.id
      }
      return nil
    @unknown default:
      return nil
    }
  }
}
