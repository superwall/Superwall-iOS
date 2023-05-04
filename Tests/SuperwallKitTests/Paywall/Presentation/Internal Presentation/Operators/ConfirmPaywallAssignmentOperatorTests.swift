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
    let request = PresentationRequest.stub()
      .setting(\.flags.isDebuggerLaunched, to: true)

    let input = PresentablePipelineOutput(
      request: request,
      debugInfo: [:],
      paywallViewController: dependencyContainer.makePaywallViewController(for: .stub(), withCache: nil),
      presenter: UIViewController(),
      confirmableAssignment: ConfirmableAssignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: ""))
    )

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .confirmPaywallAssignment()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          expectation.fulfill()
          XCTAssertFalse(configManager.confirmedAssignment)
        }
      )
      .store(in: &cancellables)

    await fulfillment(of: [expectation], timeout: 0.1)
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
    
    let request = PresentationRequest.stub()
      .setting(\.flags.isDebuggerLaunched, to: false)

    let input = PresentablePipelineOutput(
      request: request,
      debugInfo: [:],
      paywallViewController: dependencyContainer.makePaywallViewController(for: .stub(), withCache: nil),
      presenter: UIViewController(),
      confirmableAssignment: nil
    )

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .confirmPaywallAssignment()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          expectation.fulfill()
          XCTAssertFalse(configManager.confirmedAssignment)
        }
      )
      .store(in: &cancellables)

    await fulfillment(of: [expectation], timeout: 0.1)
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
      type: .getPaywallViewController
    )

    let input = PresentablePipelineOutput(
      request: request,
      debugInfo: [:],
      paywallViewController: dependencyContainer.makePaywallViewController(for: .stub(), withCache: nil),
      presenter: UIViewController(),
      confirmableAssignment: ConfirmableAssignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: ""))
    )

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .confirmPaywallAssignment()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          expectation.fulfill()
          XCTAssertTrue(configManager.confirmedAssignment)
        }
      )
      .store(in: &cancellables)

    await fulfillment(of: [expectation], timeout: 0.1)
  }
}
