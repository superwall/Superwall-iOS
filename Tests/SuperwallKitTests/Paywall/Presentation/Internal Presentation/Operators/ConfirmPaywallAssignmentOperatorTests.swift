//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class ConfirmPaywallAssignmentOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  @MainActor
  func test_confirmPaywallAssignment_debuggerLaunched() async {
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

     Superwall.shared.confirmPaywallAssignment(
      ConfirmableAssignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: "")),
      isDebuggerLaunched: true,
      dependencyContainer: dependencyContainer
     )
    XCTAssertFalse(configManager.confirmedAssignment)
  }

  @MainActor
  func test_confirmPaywallAssignment_noAssignment() async {
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


     Superwall.shared.confirmPaywallAssignment(
      nil,
      isDebuggerLaunched: false,
      dependencyContainer: dependencyContainer
     )
    XCTAssertFalse(configManager.confirmedAssignment)
  }

  @MainActor
  func test_confirmPaywallAssignment_confirmAssignment() async {
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

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywallViewController(.stub())
    )

    let input = PresentablePipelineOutput(
      debugInfo: [:],
      paywallViewController: dependencyContainer.makePaywallViewController(for: .stub(), withCache: nil, delegate: nil),
      presenter: UIViewController(),
      confirmableAssignment: ConfirmableAssignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: ""))
    )

    Superwall.shared.confirmPaywallAssignment(
      ConfirmableAssignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: "")),
      isDebuggerLaunched: false,
      dependencyContainer: dependencyContainer
     )
   XCTAssertTrue(configManager.confirmedAssignment)
  }
}
