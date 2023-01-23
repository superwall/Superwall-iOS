//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/01/2023.
//

import XCTest
@testable import SuperwallKit
import Combine

final class GetPaywallVcNoChecksOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  @MainActor
  func test_getPaywallViewController_error_userSubscribed() async {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let paywallManager = PaywallManagerMock(
      factory: dependencyContainer,
      paywallRequestManager: dependencyContainer.paywallRequestManager
    )
    paywallManager.getPaywallError = PresentationPipelineError.cancelled

    let request = PresentationRequest.stub()
      .setting(\.injections.paywallManager, to: paywallManager)
      .setting(\.injections.isUserSubscribed, to: false)

    let input = TriggerResultResponsePipelineOutput(
      request: request,
      triggerResult: .paywall(.stub()),
      debugInfo: [:],
      confirmableAssignment: nil,
      experiment: .stub()
    )

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .getPaywallViewControllerNoChecks()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure:
            expectation.fulfill()
          default:
            break
          }
        },
        receiveValue: { output in
          XCTFail()
        }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 1_000_000)

    wait(for: [expectation], timeout: 0.1)
  }

  @MainActor
  func test_getPaywallViewController() async {
    let dependencyContainer = DependencyContainer(apiKey: "")
    let paywallManager = PaywallManagerMock(
      factory: dependencyContainer,
      paywallRequestManager: dependencyContainer.paywallRequestManager
    )
    paywallManager.getPaywallVc = dependencyContainer.makePaywallViewController(for: .stub())

    let request = PresentationRequest.stub()
      .setting(\.injections.paywallManager, to: paywallManager)
      .setting(\.injections.isUserSubscribed, to: false)

    let triggerResult: TriggerResult = .paywall(.stub())
    let input = TriggerResultResponsePipelineOutput(
      request: request,
      triggerResult: triggerResult,
      debugInfo: [:],
      confirmableAssignment: nil,
      experiment: .stub()
    )

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .getPaywallViewControllerNoChecks()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          XCTFail()
        },
        receiveValue: { output in
          XCTAssertEqual(output.triggerResult, triggerResult)
          XCTAssertEqual(output.paywallViewController, paywallManager.getPaywallVc)
          XCTAssertNil(output.confirmableAssignment)
          XCTAssertTrue(output.debugInfo.isEmpty)
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 1_000_000)

    wait(for: [expectation], timeout: 0.1)
  }
}
