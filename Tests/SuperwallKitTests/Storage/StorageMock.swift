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
  var internalCachedTransactions: [StoreTransaction]
  var internalConfirmedAssignments: Set<Assignment>?
  var internalRedeemResponse: RedeemResponse?
  var internalSurveyAssignmentKey: String?
  var didClearCachedSessionEvents = false
  var didSave = false
  var saveCount = 0

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
    
    func makeSessionDeviceAttributes() async -> [String : Any] {
      return [:]
    }
  }

  init(
    internalCachedTransactions: [StoreTransaction] = [],
    internalSurveyAssignmentKey: String? = nil,
    internalRedeemResponse: RedeemResponse? = nil,
    coreDataManager: CoreDataManagerFakeDataMock = CoreDataManagerFakeDataMock(),
    confirmedAssignments: Set<Assignment>? = [],
    cache: Cache = Cache()
  ) {
    self.internalCachedTransactions = internalCachedTransactions
    self.internalConfirmedAssignments = confirmedAssignments
    self.internalSurveyAssignmentKey = internalSurveyAssignmentKey
    self.internalRedeemResponse = internalRedeemResponse
    super.init(
      factory: DeviceInfoFactoryMock(),
      cache: cache,
      coreDataManager: coreDataManager
    )
  }

  override func get<Key>(_ keyType: Key.Type) -> Key.Value? where Key : Storable {
    if keyType == Transactions.self {
      return internalCachedTransactions as? Key.Value
    } else if keyType == SurveyAssignmentKey.self {
      return internalSurveyAssignmentKey as? Key.Value
    }
    return super.get(keyType)
  }

  override func get<Key>(_ keyType: Key.Type) -> Key.Value? where Key : Storable, Key.Value : Decodable {
    if keyType == Transactions.self {
      return internalCachedTransactions as? Key.Value
    } else if keyType == SurveyAssignmentKey.self {
      return internalSurveyAssignmentKey as? Key.Value
    } else if keyType == LatestRedeemResponse.self {
      return internalRedeemResponse as? Key.Value
    }
    return super.get(keyType)
  }

  override func clearCachedSessionEvents() {
    didClearCachedSessionEvents = true
  }

  override func getAssignments() -> Set<Assignment> {
    return internalConfirmedAssignments ?? []
  }

  override func overwriteAssignments(_ newAssignments: Set<Assignment>) {
    internalConfirmedAssignments = newAssignments
  }

  override func updateAssignment(_ newAssignment: Assignment) {
    internalConfirmedAssignments?.update(with: newAssignment)
  }

  override func save<Key>(_ value: Key.Value, forType keyType: Key.Type) where Key : Storable {
    super.save(value, forType: keyType)
    didSave = true
    saveCount += 1
  }

  override func save<Key>(_ value: Key.Value, forType keyType: Key.Type) where Key : Storable, Key.Value : Encodable {
    super.save(value, forType: keyType)
    didSave = true
    saveCount += 1
  }
}
