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
      type: .getPaywall(.stub())
    )

    let input = RuleEvaluationOutcome(
      triggerResult: .holdout(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: "")))
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

    let expectation = expectation(description: "Called publisher")
    do {
      try await Superwall.shared.checkUserSubscription(
        request: request,
        triggerResult: input.triggerResult,
        paywallStatePublisher: statePublisher
      )
      XCTFail("Should throw")
    } catch {
      if let error = error as? PresentationPipelineError,
         case .userIsSubscribed = error {
        expectation.fulfill()
      }
    }

    await fulfillment(of: [expectation, stateExpectation], timeout: 0.1)
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
      type: .getPaywall(.stub())
    )

    let input = RuleEvaluationOutcome(
      triggerResult: .paywall(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: "")))
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    do {
      try await Superwall.shared.checkUserSubscription(
        request: request,
        triggerResult: input.triggerResult,
        paywallStatePublisher: statePublisher
      )
    } catch {
      XCTFail("Shouldn't throw")
    }

    await fulfillment(of: [stateExpectation], timeout: 0.1)
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
      type: .getPaywall(.stub())
    )

    let input = RuleEvaluationOutcome(
      triggerResult: .holdout(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: "")))
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    do {
      try await Superwall.shared.checkUserSubscription(
        request: request,
        triggerResult: input.triggerResult,
        paywallStatePublisher: statePublisher
      )
    } catch {
      XCTFail("Shouldn't throw")
    }

    await fulfillment(of: [stateExpectation], timeout: 0.1)
  }
}
