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
  // MARK: - Background to foreground
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

  // MARK: - Confirm Assignments
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

  // MARK: - Load Assignments

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

  // MARK: - Fetch Configuration

  func test_fetchConfiguration_success_hasBlockingAssignmentWaiting() {
    let network = NetworkMock()
    network.configReturnValue = .success(.stub())
    let storage = StorageMock()

    let requestId = "abc"
    let configManager = ConfigManagerMock(
      storage: storage,
      network: network
    )

    let triggerDelayManager = TriggerDelayManagerMock()
    triggerDelayManager.cachePreConfigAssignmentCall(.init(isBlocking: true))

    // 2. When the config has returned, check triggers haven't fired yet.
    let aboutToHandleDelayContentExpectation = expectation(description: "Handled delayed content")
    triggerDelayManager.aboutToHandleDelayedContent = {
      XCTAssertFalse(triggerDelayManager.didFireDelayedTriggers)
      aboutToHandleDelayContentExpectation.fulfill()
    }

    // 1. Fetch the config. This then fires the above completion block.
    configManager.fetchConfiguration(
      triggerDelayManager: triggerDelayManager,
      requestId: requestId
    )

    // 3. Check that the config request is set
    XCTAssertEqual(configManager.configRequestId, requestId)

    // 4. Check the triggers aren't nil
    XCTAssertNotNil(configManager.config?.triggers)

    // 5. Wait for no. 2 to complete.
    waitForExpectations(timeout: 1)

    // 6. Check that blocking assignments has loaded.
    XCTAssertTrue(configManager.hasLoadedBlockingAssignments)
    XCTAssertFalse(configManager.hasLoadedNonBlockingAssignments)

    // 7. Check that assignment calls cleared
    XCTAssertNil(triggerDelayManager.preConfigAssignmentCall)

    // 8. Check that it's now fired the delayed triggers
    XCTAssertTrue(triggerDelayManager.didFireDelayedTriggers)

  }

  func test_fetchConfiguration_success_hasNonBlockingAssignmentWaiting() {
    let network = NetworkMock()
    network.configReturnValue = .success(.stub())
    let storage = StorageMock()

    let requestId = "abc"
    let configManager = ConfigManagerMock(
      storage: storage,
      network: network
    )

    let triggerDelayManager = TriggerDelayManagerMock()
    triggerDelayManager.cachePreConfigAssignmentCall(.init(isBlocking: false))

    // 2. When the config has returned, check triggers haven't fired yet.
    let aboutToHandleDelayContentExpectation = expectation(description: "Handled delayed content")
    triggerDelayManager.aboutToHandleDelayedContent = {
      XCTAssertFalse(triggerDelayManager.didFireDelayedTriggers)
      aboutToHandleDelayContentExpectation.fulfill()
    }

    // 1. Fetch the config. This then fires the above completion block.
    configManager.fetchConfiguration(
      triggerDelayManager: triggerDelayManager,
      requestId: requestId
    )

    // 3. Check that the config request is set
    XCTAssertEqual(configManager.configRequestId, requestId)

    // 4. Check the triggers aren't nil
    XCTAssertNotNil(configManager.config?.triggers)

    // 5. Wait for no. 2 to complete.
    waitForExpectations(timeout: 1)

    // 6. Check that non-blocking assignments has loaded.
    XCTAssertFalse(configManager.hasLoadedBlockingAssignments)
    XCTAssertTrue(configManager.hasLoadedNonBlockingAssignments)

    // 7. Check that assignment calls cleared
    XCTAssertNil(triggerDelayManager.preConfigAssignmentCall)

    // 8. Check that it's now fired the delayed triggers
    XCTAssertTrue(triggerDelayManager.didFireDelayedTriggers)
  }


  func test_fetchConfiguration_success_noAssignmentsWaiting_triggersOnly() {
    let network = NetworkMock()
    network.configReturnValue = .success(.stub())
    let storage = StorageMock()

    let requestId = "abc"
    let configManager = ConfigManagerMock(
      storage: storage,
      network: network
    )

    let triggerDelayManager = TriggerDelayManagerMock()

    // 2. When the config has returned, check triggers haven't fired yet.
    let aboutToHandleDelayContentExpectation = expectation(description: "Handled delayed content")
    triggerDelayManager.aboutToHandleDelayedContent = {
      XCTAssertFalse(triggerDelayManager.didFireDelayedTriggers)
      aboutToHandleDelayContentExpectation.fulfill()
    }

    // 1. Fetch the config. This then fires the above completion block.
    configManager.fetchConfiguration(
      triggerDelayManager: triggerDelayManager,
      requestId: requestId
    )

    // 3. Check that the config request is set
    XCTAssertEqual(configManager.configRequestId, requestId)

    // 4. Check the triggers aren't nil
    XCTAssertNotNil(configManager.config?.triggers)

    // 5. Wait for no. 2 to complete.
    waitForExpectations(timeout: 1)

    // 6. Check that no assignments have been requested.
    XCTAssertFalse(configManager.hasLoadedBlockingAssignments)
    XCTAssertFalse(configManager.hasLoadedNonBlockingAssignments)

    // 7. Check that it's now fired the delayed triggers
    XCTAssertTrue(triggerDelayManager.didFireDelayedTriggers)
  }
}
