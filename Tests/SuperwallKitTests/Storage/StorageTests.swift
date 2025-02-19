//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/09/2023.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

class StorageTests: XCTestCase {
  func test_saveConfirmedAssignments() {
    let dependencyContainer = DependencyContainer()
    let storage = Storage(factory: dependencyContainer)
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      factory: dependencyContainer
    )

    let assignments = Set([
      Assignment(
        experimentId: "123",
        variant: .init(id: "1", type: .treatment, paywallId: "23"),
        isSentToServer: false
      )
    ])
    storage.saveAssignments(assignments)

    let retrievedAssignments = storage.getAssignments()
    XCTAssertEqual(retrievedAssignments.first, assignments.first)

    storage.reset()
    configManager.reset()

    let retrievedAssignments2 = storage.getAssignments()
    XCTAssertTrue(retrievedAssignments2.isEmpty)
  }
}

