//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

@testable import Paywall
import XCTest

@available(iOS 14.0, *)
final class ConfigManagerTests: XCTestCase {
  func test_backgroundToForeground_noConfig() {
    let network = NetworkMock()
    NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )
    XCTAssertFalse(network.getConfigCalled)
  }

  func test_backgroundToForeground_storedConfig() {
    let configRequest = ConfigRequest(
      id: "abc",
      completion: { _ in }
    )
    let network = NetworkMock()
    let configManager = ConfigManager(
      network: network
    )
    configManager.configRequest = configRequest


    NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )
    XCTAssertTrue(network.getConfigCalled)
  }

  func test_confirmAssignments() {
    let network = NetworkMock()
    let storage = StorageMock()

    let experimentId = "abc"
    let variantId = "def"
    let variant: Experiment.Variant = .init(id: variantId, type: .treatment, paywallId: "jkl")
    let assignment = ConfirmableAssignment(
      experimentId: experimentId,
      variant: variant
    )
    let configManager = ConfigManager(storage: storage, network: network)

    configManager.confirmAssignments(assignment)

    XCTAssertTrue(network.assignmentsConfirmed)
    XCTAssertEqual(storage.getConfirmedAssignments()[experimentId], variant)
    XCTAssertNil(configManager.unconfirmedAssignments[experimentId])
  }

  func test_loadAssignments_noConfig() {
    let network = NetworkMock()
    let storage = StorageMock()
    let configManager = ConfigManager(storage: storage, network: network)
    configManager.config = nil

    let expectation = expectation(description: "load assignments")
    configManager.loadAssignments {
      expectation.fulfill()
    }
    waitForExpectations(timeout: 1)

    XCTAssertTrue(storage.getConfirmedAssignments().isEmpty)
    XCTAssertTrue(configManager.unconfirmedAssignments.isEmpty)
  }

  func test_loadAssignments_noTriggers() {
    let network = NetworkMock()
    let storage = StorageMock()
    let configManager = ConfigManager(storage: storage, network: network)
    configManager.config = .stub()
      .setting(\.triggers, to: [])

    let expectation = expectation(description: "load assignments")
    configManager.loadAssignments {
      expectation.fulfill()
    }
    waitForExpectations(timeout: 1)

    XCTAssertTrue(storage.getConfirmedAssignments().isEmpty)
    XCTAssertTrue(configManager.unconfirmedAssignments.isEmpty)
  }

  func test_loadAssignments_saveAssignmentsFromServer() {
    let network = NetworkMock()
    let storage = StorageMock()

    let variantId = "variantId"
    let experimentId = "experimentId"

    let assignments: [Assignment] = [
      Assignment(experimentId: experimentId, variantId: variantId)
    ]
    network.assignments = assignments

    let variantOption: VariantOption = .stub()
      .setting(\.id, to: variantId)
    let configManager = ConfigManager(storage: storage, network: network)
    configManager.config = .stub()
      .setting(\.triggers, to: [
        .stub()
        .setting(\.rules, to: [
          .stub()
          .setting(\.experiment.id, to: experimentId)
          .setting(\.experiment.variants, to: [
            variantOption
          ])
        ])
      ])

    let expectation = expectation(description: "load assignments")
    configManager.loadAssignments {
      expectation.fulfill()
    }
    waitForExpectations(timeout: 1)

    XCTAssertEqual(storage.getConfirmedAssignments()[experimentId], variantOption.toVariant())
    XCTAssertTrue(configManager.unconfirmedAssignments.isEmpty)
  }
}
