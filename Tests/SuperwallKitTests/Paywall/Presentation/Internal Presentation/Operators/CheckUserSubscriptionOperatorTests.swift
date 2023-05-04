//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class CheckUserSubscriptionOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_checkUserSubscription_notPaywall_userSubscribed() async {
    let publisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()

    let dependencyContainer = DependencyContainer()
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      subscriptionStatus: publisher,
      isPaywallPresented: false,
      type: .getPaywallViewController
    )

    let input = AssignmentPipelineOutput(
      request: request,
      triggerResult: .holdout(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      debugInfo: [:]
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")

    statePublisher.sink { state in
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

    let pipelineExpectation = expectation(description: "Continued pipeline")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkUserSubscription(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure:
            pipelineExpectation.fulfill()
          default:
            break
          }

        },
        receiveValue: { _ in }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 10_000_000)

    await fulfillment(of: [pipelineExpectation, stateExpectation], timeout: 0.1)
  }

  func test_checkUserSubscription_paywall() async {
    let publisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    let dependencyContainer = DependencyContainer()
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      subscriptionStatus: publisher,
      isPaywallPresented: false,
      type: .getPaywallViewController
    )

    let input = AssignmentPipelineOutput(
      request: request,
      triggerResult: .paywall(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      debugInfo: [:]
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    let pipelineExpectation = expectation(description: "Continued pipeline")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkUserSubscription(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          pipelineExpectation.fulfill()
        }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 10_000_000)

    await fulfillment(of: [pipelineExpectation, stateExpectation], timeout: 0.1)
  }

  func test_checkUserSubscription_notPaywall_userNotSubscribed() async {
    let publisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    let dependencyContainer = DependencyContainer()
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      subscriptionStatus: publisher,
      isPaywallPresented: false,
      type: .getPaywallViewController
    )

    let input = AssignmentPipelineOutput(
      request: request,
      triggerResult: .holdout(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      debugInfo: [:]
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    let pipelineExpectation = expectation(description: "Continued pipeline")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkUserSubscription(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          pipelineExpectation.fulfill()
        }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 10_000_000)

    await fulfillment(of: [pipelineExpectation, stateExpectation], timeout: 0.1)
  }
}
