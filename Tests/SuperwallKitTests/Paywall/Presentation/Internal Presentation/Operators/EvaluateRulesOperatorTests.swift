//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class EvaluateRulesOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_evaluateRules_isDebugger() async {
    let dependencyContainer = DependencyContainer()
    let identifier = "abc"

    let inactiveSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()
    let request = dependencyContainer.makePresentationRequest(
      .fromIdentifier(identifier, freeTrialOverride: false),
      isDebuggerLaunched: true,
      subscriptionStatus: inactiveSubscriptionPublisher,
      isPaywallPresented: false,
      type: .getPaywallViewController(.stub())
    )

    let debugInfo: [String: Any] = [:]
    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject((request, debugInfo))
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .evaluateRules()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          XCTAssertNil(output.confirmableAssignment)

          switch output.triggerResult {
          case .paywall(let experiment):
            XCTAssertEqual(experiment.id, identifier)
            XCTAssertEqual(experiment.groupId, "")
            XCTAssertEqual(experiment.variant.id, "")
            XCTAssertEqual(experiment.variant.type, .treatment)
            XCTAssertEqual(experiment.variant.paywallId, identifier)
          default:
            XCTFail("Wrong trigger result")
          }
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 100_000_000)

    await fulfillment(of: [expectation], timeout: 0.1)
  }

  func test_evaluateRules_isNotDebugger() async {
    let inactiveSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()
    let dependencyContainer = DependencyContainer()
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      subscriptionStatus: inactiveSubscriptionPublisher,
      isPaywallPresented: false,
      type: .getPaywallViewController(.stub())
    )

    let debugInfo: [String: Any] = [:]
    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject((request, debugInfo))
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .evaluateRules()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          XCTAssertNil(output.confirmableAssignment)

          switch output.triggerResult {
          case .eventNotFound:
            expectation.fulfill()
          default:
            break
          }
        }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 100_000_000)

    await fulfillment(of: [expectation], timeout: 0.1)
  }
}
