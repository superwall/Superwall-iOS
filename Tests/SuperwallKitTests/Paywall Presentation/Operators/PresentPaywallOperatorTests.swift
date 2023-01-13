//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class PresentPaywallOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_presentPaywall_isPresented() {
    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")

    statePublisher.sink { completion in
      XCTFail()
    } receiveValue: { state in
      switch state {
      case .presented:
        stateExpectation.fulfill()
      default:
        break
      }
    }
    .store(in: &cancellables)
    let dependencyContainer = DependencyContainer(apiKey: "")
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      identityManager: dependencyContainer.identityManager
    )
    paywallVc.shouldPresent = true

    let input = PresentablePipelineOutput(
      request: .stub(),
      debugInfo: [:],
      paywallViewController: paywallVc,
      presenter: UIViewController(),
      confirmableAssignment: nil
    )

    let expectation = expectation(description: "Got identity")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .presentPaywall(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation, stateExpectation], timeout: 0.1)
  }

  func test_presentPaywall_isNotPresented() {
    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      default:
        break
      }
    } receiveValue: { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .error:
          stateExpectation.fulfill()
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    let dependencyContainer = DependencyContainer(apiKey: "")
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      identityManager: dependencyContainer.identityManager
    )
    paywallVc.shouldPresent = false

    let input = PresentablePipelineOutput(
      request: .stub(),
      debugInfo: [:],
      paywallViewController: paywallVc,
      presenter: UIViewController(),
      confirmableAssignment: nil
    )

    let expectation = expectation(description: "Got identity")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .presentPaywall(statePublisher)
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
        receiveValue: { value in
          XCTFail()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation, stateExpectation], timeout: 0.1)
  }
}
