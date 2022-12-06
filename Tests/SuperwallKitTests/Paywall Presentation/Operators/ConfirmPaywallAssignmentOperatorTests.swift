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
    let configManager = ConfigManagerMock()
    let request = PresentationRequest.stub()
      .setting(\.injections.isDebuggerLaunched, to: true)
      .setting(\.injections.configManager, to: configManager)

    let input = PresentablePipelineOutput(
      request: request,
      debugInfo: [:],
      paywallViewController: PaywallViewController(paywall: .stub()),
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

    wait(for: [expectation], timeout: 0.1)
  }

  @MainActor
  func test_confirmPaywallAssignment_noAssignment() async {
    let configManager = ConfigManagerMock()
    let request = PresentationRequest.stub()
      .setting(\.injections.isDebuggerLaunched, to: false)
      .setting(\.injections.configManager, to: configManager)

    let input = PresentablePipelineOutput(
      request: request,
      debugInfo: [:],
      paywallViewController: PaywallViewController(paywall: .stub()),
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

    wait(for: [expectation], timeout: 0.1)
  }

  @MainActor
  func test_confirmPaywallAssignment_confirmAssignment() async {
    let configManager = ConfigManagerMock()
    let request = PresentationRequest.stub()
      .setting(\.injections.isDebuggerLaunched, to: false)
      .setting(\.injections.configManager, to: configManager)

    let input = PresentablePipelineOutput(
      request: request,
      debugInfo: [:],
      paywallViewController: PaywallViewController(paywall: .stub()),
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

    wait(for: [expectation], timeout: 0.1)
  }
}
