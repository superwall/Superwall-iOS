//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//
// swiftlint:disable all

import Foundation
@testable import Paywall

@available(iOS 14.0, *)
final class StorageMock: Storage {
  var internalCachedTriggerSessions: [TriggerSession]
  var internalCachedTransactions: [TransactionModel]
  var internalConfirmedAssignments: [Experiment.ID: Experiment.Variant]
  var didClearCachedSessionEvents = false

  init(
    internalCachedTriggerSessions: [TriggerSession] = [],
    internalCachedTransactions: [TransactionModel] = [],
    coreDataManager: CoreDataManagerFakeDataMock = CoreDataManagerFakeDataMock(),
    confirmedAssignments: [Experiment.ID : Experiment.Variant] = [:]
  ) {
    self.internalCachedTriggerSessions = internalCachedTriggerSessions
    self.internalCachedTransactions = internalCachedTransactions
    self.internalConfirmedAssignments = confirmedAssignments
    super.init(coreDataManager: coreDataManager)
  }

  override func getCachedTriggerSessions() -> [TriggerSession] {
    return internalCachedTriggerSessions
  }

  override func getCachedTransactions() -> [TransactionModel] {
    return internalCachedTransactions
  }

  override func clearCachedSessionEvents() {
    didClearCachedSessionEvents = true
  }

  override func getConfirmedAssignments() -> [Experiment.ID: Experiment.Variant] {
    return internalConfirmedAssignments
  }

  override func saveConfirmedAssignments(_ assignments: [String : Experiment.Variant]) {
    internalConfirmedAssignments = assignments
  }
}
