//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

@testable import SuperwallKit
import XCTest

@available(iOS 14.0, *)
final class ConfigManagerTests: XCTestCase {
  func test_refreshConfiguration() async {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(factory: dependencyContainer)
    let newConfig: Config = .stub()
      .setting(\.buildId, to: "123")
    network.configReturnValue = .success(newConfig)

    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer
    )

    let oldConfig: Config = .stub()
      .setting(\.buildId, to: "abc")
    configManager.configState.send(.retrieved(oldConfig))

    await configManager.refreshConfiguration()

    XCTAssertEqual(configManager.config?.buildId, "123")
  }

  // MARK: - Confirm Assignments
  func test_confirmAssignment() async {
    let experimentId = "abc"
    let variantId = "def"
    let variant: Experiment.Variant = .init(id: variantId, type: .treatment, paywallId: "jkl")
    let assignment = ConfirmableAssignment(
      experimentId: experimentId,
      variant: variant
    )
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(factory: dependencyContainer)
    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer
    )
    configManager.confirmAssignment(assignment)

    let milliseconds = 200
    let nanoseconds = UInt64(milliseconds * 1_000_000)
    try? await Task.sleep(nanoseconds: nanoseconds)

    XCTAssertTrue(network.assignmentsConfirmed)
    XCTAssertEqual(storage.getConfirmedAssignments()[experimentId], variant)
    XCTAssertNil(configManager.unconfirmedAssignments[experimentId])
  }

  // MARK: - Load Assignments

  func test_loadAssignments_noConfig() async {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(factory: dependencyContainer)
    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer
    )

    let expectation = expectation(description: "No assignments")
    expectation.isInverted = true
    Task {
      try? await configManager.getAssignments()
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 1)

    XCTAssertTrue(storage.getConfirmedAssignments().isEmpty)
    XCTAssertTrue(configManager.unconfirmedAssignments.isEmpty)
  }

  func test_loadAssignments_noTriggers() async {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(factory: dependencyContainer)
    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer
    )
    configManager.configState.send(.retrieved(.stub()
      .setting(\.triggers, to: [])))

    try? await configManager.getAssignments()

    XCTAssertTrue(storage.getConfirmedAssignments().isEmpty)
    XCTAssertTrue(configManager.unconfirmedAssignments.isEmpty)
  }

  func test_loadAssignments_saveAssignmentsFromServer() async {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(factory: dependencyContainer)
    let storage = StorageMock()
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer
    )

    let variantId = "variantId"
    let experimentId = "experimentId"

    let assignments: [Assignment] = [
      Assignment(experimentId: experimentId, variantId: variantId)
    ]
    network.assignments = assignments

    let variantOption: VariantOption = .stub()
      .setting(\.id, to: variantId)
    configManager.configState.send(.retrieved(.stub()
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
    ))

    try? await configManager.getAssignments()

    try? await Task.sleep(nanoseconds: 1_000_000)

    XCTAssertEqual(storage.getConfirmedAssignments()[experimentId], variantOption.toVariant())
    XCTAssertTrue(configManager.unconfirmedAssignments.isEmpty)
  }
}
