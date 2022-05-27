//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import Foundation
import StoreKit

final class TransactionManager {
  private weak var delegate: SessionEventsDelegate?

  /// Storage class. Can be injected via init for testing.
  private let storage: Storage

  /// Only instantiate this if you're testing. Otherwise use `TriggerSessionManager.shared`.
  init(
    delegate: SessionEventsDelegate,
    storage: Storage = Storage.shared
  ) {
    self.delegate = delegate
    self.storage = storage
  }

  func record(_ transaction: SKPaymentTransaction) {
    let transaction = TransactionModel(
      from: transaction,
      configRequestId: storage.configRequestId,
      appSessionId: AppSessionManager.shared.appSession.id,
      triggerSessionId: delegate?.triggerSession.activeTriggerSession?.id
    )
    delegate?.enqueue(transaction)
  }
}
