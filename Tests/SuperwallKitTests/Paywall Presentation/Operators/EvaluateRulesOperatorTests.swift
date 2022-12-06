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
    let identifier = "abc"
    let request = PresentationRequest(
      presentationInfo: .fromIdentifier(identifier, freeTrialOverride: false),
      injections: .init(
        isDebuggerLaunched: true,
        isUserSubscribed: false,
        isPaywallPresented: false
      )
    )

    let debugInfo: [String: Any] = [:]
    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject((request, debugInfo))
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .evaluateRules(isPreemptive: false)
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

    wait(for: [expectation], timeout: 0.1)
  }

  func test_evaluateRules_isNotDebugger() async {
    let request = PresentationRequest(
      presentationInfo: .explicitTrigger(.stub()),
      injections: .init(
        isDebuggerLaunched: false,
        isUserSubscribed: false,
        isPaywallPresented: false
      )
    )

    let debugInfo: [String: Any] = [:]
    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject((request, debugInfo))
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .evaluateRules(isPreemptive: false)
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

    wait(for: [expectation], timeout: 0.1)
  }
}
