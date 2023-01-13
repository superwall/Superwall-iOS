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
    let dependencyContainer = DependencyContainer(apiKey: "")
    let identifier = "abc"
    let request = PresentationRequest(
      presentationInfo: .fromIdentifier(identifier, freeTrialOverride: false),
      injections: .init(
        configManager: dependencyContainer.configManager,
        storage: dependencyContainer.storage,
        sessionEventsManager: dependencyContainer.sessionEventsManager,
        paywallManager: dependencyContainer.paywallManager,
        storeKitManager: dependencyContainer.storeKitManager,
        network: dependencyContainer.network,
        debugManager: dependencyContainer.debugManager,
        identityManager: dependencyContainer.identityManager,
        deviceHelper: dependencyContainer.deviceHelper,
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
    let dependencyContainer = DependencyContainer(apiKey: "")
    let request = PresentationRequest(
      presentationInfo: .explicitTrigger(.stub()),
      injections: .init(
        configManager: dependencyContainer.configManager,
        storage: dependencyContainer.storage,
        sessionEventsManager: dependencyContainer.sessionEventsManager,
        paywallManager: dependencyContainer.paywallManager,
        storeKitManager: dependencyContainer.storeKitManager,
        network: dependencyContainer.network,
        debugManager: dependencyContainer.debugManager,
        identityManager: dependencyContainer.identityManager,
        deviceHelper: dependencyContainer.deviceHelper,
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
