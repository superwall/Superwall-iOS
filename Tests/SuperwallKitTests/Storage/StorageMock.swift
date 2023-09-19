//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//
// swiftlint:disable all

import Foundation
@testable import SuperwallKit

@available(iOS 14.0, *)
final class StorageMock: Storage {
  var internalCachedTriggerSessions: [TriggerSession]
  var internalCachedTransactions: [StoreTransaction]
  var internalConfirmedAssignments: [Experiment.ID: Experiment.Variant]
  var internalSurveyAssignmentKey: String?
  var didClearCachedSessionEvents = false
  var didSave = false

  class DeviceInfoFactoryMock: DeviceHelperFactory, HasExternalPurchaseControllerFactory {
    func makeDeviceInfo() -> DeviceInfo {
      return DeviceInfo(appInstalledAtString: "a", locale: "b")
    }

    func makeIsSandbox() -> Bool {
      return true
    }

    func makeHasExternalPurchaseController() -> Bool {
      return false
    }
  }

  init(
    internalCachedTriggerSessions: [TriggerSession] = [],
    internalCachedTransactions: [StoreTransaction] = [],
    internalSurveyAssignmentKey: String? = nil,
    coreDataManager: CoreDataManagerFakeDataMock = CoreDataManagerFakeDataMock(),
    confirmedAssignments: [Experiment.ID : Experiment.Variant] = [:],
    cache: Cache = Cache()
  ) {
    self.internalCachedTriggerSessions = internalCachedTriggerSessions
    self.internalCachedTransactions = internalCachedTransactions
    self.internalConfirmedAssignments = confirmedAssignments
    self.internalSurveyAssignmentKey = internalSurveyAssignmentKey

    super.init(factory: DeviceInfoFactoryMock(), cache: cache, coreDataManager: coreDataManager)
  }

  override func get<Key>(_ keyType: Key.Type) -> Key.Value? where Key : Storable {
    if keyType == TriggerSessions.self {
      return internalCachedTriggerSessions as? Key.Value
    } else if keyType == Transactions.self {
      return internalCachedTransactions as? Key.Value
    } else if keyType == SurveyAssignmentKey.self {
      return internalSurveyAssignmentKey as? Key.Value
    }
    return super.get(keyType)
  }

  override func get<Key>(_ keyType: Key.Type) -> Key.Value? where Key : Storable, Key.Value : Decodable {
    if keyType == TriggerSessions.self {
      return internalCachedTriggerSessions as? Key.Value
    } else if keyType == Transactions.self {
      return internalCachedTransactions as? Key.Value
    } else if keyType == SurveyAssignmentKey.self {
      return internalSurveyAssignmentKey as? Key.Value
    }
    return super.get(keyType)
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

  override func save<Key>(_ value: Key.Value, forType keyType: Key.Type) where Key : Storable {
    super.save(value, forType: keyType)
    didSave = true
  }

  override func save<Key>(_ value: Key.Value, forType keyType: Key.Type) where Key : Storable, Key.Value : Encodable {
    super.save(value, forType: keyType)
    didSave = true
  }
}
