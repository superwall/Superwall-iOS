//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import Foundation
import StoreKit

final class TransactionRecorder {
  /// Storage class. Can be injected via init for testing.
  private let storage: Storage

  /// Config manager class. Can be injected via init for testing.
  private let configManager: ConfigManager

  /// App session manager that can be injected via init for testing.
  private let appSessionManager: AppSessionManager

  /// Session events manager that can be injected via init for testing.
  private let sessionEventsManager: SessionEventsManager

  /// Only instantiate this if you're testing. Otherwise use `TriggerSessionManager.shared`.
  init(
    storage: Storage = .shared,
    configManager: ConfigManager = .shared,
    sessionEventsManager: SessionEventsManager = .shared,
    appSessionManager: AppSessionManager = AppSessionManager.shared
  ) {
    self.sessionEventsManager = sessionEventsManager
    self.storage = storage
    self.configManager = configManager
    self.appSessionManager = appSessionManager
  }

  func record(_ transaction: SKPaymentTransaction) async {
    let triggerSession = await sessionEventsManager.triggerSession.activeTriggerSession
    let triggerSessionId = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: triggerSession
    )

    let transaction = TransactionModel(
      from: transaction,
      configRequestId: configManager.config?.requestId ?? "",
      appSessionId: appSessionManager.appSession.id,
      triggerSessionId: triggerSessionId
    )

    sessionEventsManager.enqueue(transaction)
  }

  @available(iOS 15.0, *)
  func record(_ transaction: Transaction) async {
    let triggerSession = await sessionEventsManager.triggerSession.activeTriggerSession
    var triggerSessionId: String?
    if triggerSession?.transaction != nil {
      triggerSessionId = triggerSession?.id
    }

    let transaction = TransactionModel(
      from: transaction,
      configRequestId: configManager.config?.requestId ?? "",
      appSessionId: appSessionManager.appSession.id,
      triggerSessionId: triggerSessionId
    )

    sessionEventsManager.enqueue(transaction)
  }
}
