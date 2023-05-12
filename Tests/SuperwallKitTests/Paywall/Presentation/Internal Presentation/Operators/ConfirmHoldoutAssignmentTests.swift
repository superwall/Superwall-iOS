//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class ConfirmHoldoutAssignmentOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_confirmHoldoutAssignment_notHoldout() async {
    let dependencyContainer = DependencyContainer()

    let configManager = ConfigManagerMock(
      options: nil,
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      factory: dependencyContainer
    )

    try? await Task.sleep(nanoseconds: 10_000_000)

    dependencyContainer.configManager = configManager

    let input = AssignmentPipelineOutput(
      triggerResult: .paywall(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      debugInfo: [:]
    )

    Superwall.shared.confirmHoldoutAssignment(
      input: input,
      dependencyContainer: dependencyContainer
    )
    XCTAssertFalse(configManager.confirmedAssignment)
  }

  func test_confirmHoldoutAssignment_holdout_noConfirmableAssignments() async {
    let dependencyContainer = DependencyContainer()
    let configManager = ConfigManagerMock(
      options: nil,
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      factory: dependencyContainer
    )

    try? await Task.sleep(nanoseconds: 10_000_000)

    dependencyContainer.configManager = configManager

    let input = AssignmentPipelineOutput(
      triggerResult: .holdout(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      confirmableAssignment: nil,
      debugInfo: [:]
    )

    Superwall.shared.confirmHoldoutAssignment(
      input: input,
      dependencyContainer: dependencyContainer
    )
    XCTAssertFalse(configManager.confirmedAssignment)
  }

  func test_confirmHoldoutAssignment_holdout_hasConfirmableAssignments() async {
    let dependencyContainer = DependencyContainer()
    let configManager = ConfigManagerMock(
      options: nil,
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      factory: dependencyContainer
    )
    try? await Task.sleep(nanoseconds: 10_000_000)

    dependencyContainer.configManager = configManager

    let input = AssignmentPipelineOutput(
      triggerResult: .holdout(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      confirmableAssignment: .init(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: "")),
      debugInfo: [:]
    )

    Superwall.shared.confirmHoldoutAssignment(
      input: input,
      dependencyContainer: dependencyContainer
    )
    XCTAssertTrue(configManager.confirmedAssignment)
  }
}
