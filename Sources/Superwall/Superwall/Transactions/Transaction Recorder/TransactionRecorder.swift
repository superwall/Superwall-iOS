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

  /// Sends the transaction back to the server with other session events.
  ///
  /// - Returns: A model of the transaction
  @discardableResult
  func record(_ transaction: SKPaymentTransaction) async -> TransactionModel {
    let triggerSessionId = await getTriggerSessionId()

    let transaction = TransactionModel(
      from: transaction,
      configRequestId: configManager.config?.requestId ?? "",
      appSessionId: appSessionManager.appSession.id,
      triggerSessionId: triggerSessionId
    )

    Task.detached(priority: .utility) { [weak self] in
      await self?.sessionEventsManager.enqueue(transaction)
    }

    return transaction
  }

  /// Sends the transaction back to the server with other session events.
  ///
  /// - Returns: A model of the transaction
  @discardableResult
  @available(iOS 15.0, *)
  func record(_ transaction: Transaction) async -> TransactionModel {
    let triggerSessionId = await getTriggerSessionId()

    let transaction = TransactionModel(
      from: transaction,
      configRequestId: configManager.config?.requestId ?? "",
      appSessionId: appSessionManager.appSession.id,
      triggerSessionId: triggerSessionId
    )

    Task.detached(priority: .utility) { [weak self] in
      await self?.sessionEventsManager.enqueue(transaction)
    }

    return transaction
  }

  private func getTriggerSessionId() async -> String? {
    let triggerSession = await sessionEventsManager.triggerSession.activeTriggerSession
    var triggerSessionId: String?
    if triggerSession?.transaction != nil {
      triggerSessionId = triggerSession?.id
    }
    return triggerSessionId
  }
}
