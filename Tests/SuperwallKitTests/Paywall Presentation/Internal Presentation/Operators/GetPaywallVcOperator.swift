//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class GetPaywallVcOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  @MainActor
  func test_getPaywallViewController_error_userSubscribed() async {
    let experiment = Experiment(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      }
    } receiveValue: { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .userIsSubscribed:
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
    let paywallManager = PaywallManagerMock(
      factory: dependencyContainer,
      paywallRequestManager: dependencyContainer.paywallRequestManager
    )
    paywallManager.getPaywallError = PresentationPipelineError.cancelled

    let request = PresentationRequest.stub()
      .setting(\.injections.paywallManager, to: paywallManager)
      .setting(\.injections.isUserSubscribed, to: true)

    let input = TriggerResultResponsePipelineOutput(
      request: request,
      triggerResult: .paywall(experiment),
      debugInfo: [:],
      confirmableAssignment: nil,
      experiment: experiment
    )

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .getPaywallViewController(statePublisher)
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

    wait(for: [expectation, stateExpectation], timeout: 0.1)
  }

  @MainActor
  func test_getPaywallViewController_error_userNotSubscribed() async {
    let experiment = Experiment(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
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
      triggerResult: .paywall(experiment),
      debugInfo: [:],
      confirmableAssignment: nil,
      experiment: experiment
    )

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .getPaywallViewController(statePublisher)
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

    wait(for: [expectation, stateExpectation], timeout: 0.1)
  }

  @MainActor
  func test_getPaywallViewController_success_paywallAlreadyPresented() async {
    let experiment = Experiment(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
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
    let paywallManager = PaywallManagerMock(
      factory: dependencyContainer,
      paywallRequestManager: dependencyContainer.paywallRequestManager
    )
    paywallManager.getPaywallVc = dependencyContainer.makePaywallViewController(for: .stub())

    let request = PresentationRequest.stub()
      .setting(\.injections.paywallManager, to: paywallManager)
      .setting(\.injections.isPaywallPresented, to: true)

    let input = TriggerResultResponsePipelineOutput(
      request: request,
      triggerResult: .paywall(experiment),
      debugInfo: [:],
      confirmableAssignment: nil,
      experiment: experiment
    )

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .getPaywallViewController(statePublisher)
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

    wait(for: [expectation, stateExpectation], timeout: 0.1)
  }

  @MainActor
  func test_getPaywallViewController_success_paywallNotAlreadyPresented() async {
    let experiment = Experiment(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { _ in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    let dependencyContainer = DependencyContainer(apiKey: "")
    let paywallManager = PaywallManagerMock(
      factory: dependencyContainer,
      paywallRequestManager: dependencyContainer.paywallRequestManager
    )
    paywallManager.getPaywallVc = dependencyContainer.makePaywallViewController(for: .stub())

    let request = PresentationRequest.stub()
      .setting(\.injections.paywallManager, to: paywallManager)
      .setting(\.injections.isPaywallPresented, to: false)

    let input = TriggerResultResponsePipelineOutput(
      request: request,
      triggerResult: .paywall(experiment),
      debugInfo: [:],
      confirmableAssignment: nil,
      experiment: experiment
    )

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .getPaywallViewController(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          XCTFail()
        },
        receiveValue: { output in
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 1_000_000)

    wait(for: [expectation, stateExpectation], timeout: 0.1)
  }
}
