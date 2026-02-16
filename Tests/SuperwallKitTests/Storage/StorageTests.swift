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
  func test_overwriteAssignments() {
    let dependencyContainer = DependencyContainer()
    let storage = Storage(factory: dependencyContainer)
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )

    let assignments = Set([
      Assignment(
        experimentId: "123",
        variant: .init(id: "1", type: .treatment, paywallId: "23"),
        isSentToServer: false
      )
    ])
    storage.overwriteAssignments(assignments)

    let retrievedAssignments = storage.getAssignments()
    XCTAssertEqual(retrievedAssignments.first, assignments.first)

    storage.reset()

    let retrievedAssignments2 = storage.getAssignments()
    XCTAssertTrue(retrievedAssignments2.isEmpty)
  }
}

