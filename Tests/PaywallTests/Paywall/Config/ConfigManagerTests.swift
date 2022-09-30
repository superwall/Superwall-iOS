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
  // MARK: - Confirm Assignments
  func test_confirmAssignments() async {
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

    let twoHundredMilliseconds = UInt64(200_000_000)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)

    XCTAssertTrue(network.assignmentsConfirmed)
    XCTAssertEqual(storage.getConfirmedAssignments()[experimentId], variant)
    XCTAssertNil(configManager.unconfirmedAssignments[experimentId])
  }

  // MARK: - Load Assignments

  func test_loadAssignments_noConfig() async {
    let network = NetworkMock()
    let storage = StorageMock()
    let configManager = ConfigManager(storage: storage, network: network)
    configManager.config = nil

    await configManager.getAssignments()

    XCTAssertTrue(storage.getConfirmedAssignments().isEmpty)
    XCTAssertTrue(configManager.unconfirmedAssignments.isEmpty)
  }

  func test_loadAssignments_noTriggers() async {
    let network = NetworkMock()
    let storage = StorageMock()
    let configManager = ConfigManager(storage: storage, network: network)
    configManager.config = .stub()
      .setting(\.triggers, to: [])

    await configManager.getAssignments()

    XCTAssertTrue(storage.getConfirmedAssignments().isEmpty)
    XCTAssertTrue(configManager.unconfirmedAssignments.isEmpty)
  }

  func test_loadAssignments_saveAssignmentsFromServer() async {
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

    await configManager.getAssignments()

    XCTAssertEqual(storage.getConfirmedAssignments()[experimentId], variantOption.toVariant())
    XCTAssertTrue(configManager.unconfirmedAssignments.isEmpty)
  }
}
