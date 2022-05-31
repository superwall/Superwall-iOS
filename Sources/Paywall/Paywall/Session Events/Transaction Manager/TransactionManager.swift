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

  /// App session manager that can be injected via init for testing.
  private let appSessionManager: AppSessionManager

  /// Only instantiate this if you're testing. Otherwise use `TriggerSessionManager.shared`.
  init(
    delegate: SessionEventsDelegate,
    storage: Storage = Storage.shared,
    appSessionManager: AppSessionManager = AppSessionManager.shared
  ) {
    self.delegate = delegate
    self.storage = storage
    self.appSessionManager = appSessionManager
  }

  func record(_ transaction: SKPaymentTransaction) {
    let triggerSession = delegate?.triggerSession.activeTriggerSession
    let triggerSessionId = TransactionManagerLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: triggerSession
    )

    let transaction = TransactionModel(
      from: transaction,
      configRequestId: storage.configRequestId,
      appSessionId: appSessionManager.appSession.id,
      triggerSessionId: triggerSessionId
    )

    delegate?.enqueue(transaction)
  }
}
