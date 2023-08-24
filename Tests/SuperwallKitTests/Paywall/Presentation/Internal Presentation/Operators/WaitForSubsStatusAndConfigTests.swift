//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class WaitForSubsStatusAndConfigTests: XCTestCase {
  var cancellables: [AnyCancellable] = []
  let dependencyContainer = DependencyContainer()
  var identityManager: IdentityManager {
    return dependencyContainer.identityManager
  }
  
  override func setUp() async throws {
    identityManager.reset(duringIdentify: false)
  }

  func test_waitForSubsStatusAndConfig_noIdentity_unknownStatus() {
    let expectation1 = expectation(description: "Got identity")
    expectation1.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.unknown)
      .eraseToAnyPublisher()
    let request = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    Task {
      try await Superwall.shared.waitForSubsStatusAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      expectation1.fulfill()
    }

    wait(for: [expectation1, stateExpectation], timeout: 5.5)
  }

  func test_waitToPresent_noIdentity_unknownStatus_becomesActive() {
    let expectation1 = expectation(description: "Got identity")

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.unknown)
    let request = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher.eraseToAnyPublisher())

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      stateExpectation.fulfill()
      unknownSubscriptionPublisher.send(.active)
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    Task {
      do {
        try await Superwall.shared.waitForSubsStatusAndConfig(
          request,
          paywallStatePublisher: statePublisher,
          dependencyContainer: dependencyContainer
        )
      } catch {
        expectation1.fulfill()
      }
    }

    wait(for: [expectation1, stateExpectation], timeout: 5.5)
  }

  func test_waitForSubsStatusAndConfig_activeStatus_noConfigEvenAfterDelay() {
    let expectation1 = expectation(description: "Got identity")

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let stub = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    Task {
      do {
        try await Superwall.shared.waitForSubsStatusAndConfig(
          stub,
          paywallStatePublisher: statePublisher,
          dependencyContainer: dependencyContainer
        )
        XCTFail()
      } catch {
        expectation1.fulfill()
      }
    }

    wait(for: [expectation1, stateExpectation], timeout: 1.1)
  }

  func test_waitForSubsStatusAndConfig_activeStatus_noConfig_configFailedState() {
    let expectation1 = expectation(description: "Got identity")

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let stub = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)


    dependencyContainer.configManager.configState.send(.failed)

    Task {
      do {
        try await Superwall.shared.waitForSubsStatusAndConfig(
          stub,
          paywallStatePublisher: statePublisher,
          dependencyContainer: dependencyContainer
        )
        XCTFail()
      } catch {
        expectation1.fulfill()
      }
    }

    wait(for: [expectation1, stateExpectation], timeout: 0.1)
  }

  func test_waitForSubsStatusAndConfig_activeStatus_noConfig_configRetryingState() {
    let expectation1 = expectation(description: "Got identity")

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let stub = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)


    dependencyContainer.configManager.configState.send(.retrying)

    Task {
      do {
        try await Superwall.shared.waitForSubsStatusAndConfig(
          stub,
          paywallStatePublisher: statePublisher,
          dependencyContainer: dependencyContainer
        )
        XCTFail()
      } catch {
        expectation1.fulfill()
      }
    }

    wait(for: [expectation1, stateExpectation], timeout: 0.1)
  }

  func test_waitForSubsStatusAndConfig_activeStatus_noConfig_hasConfigAfterDelay() {
    let expectation1 = expectation(description: "Got identity")

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let stub = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    let statePublisher = PassthroughSubject<PaywallState, Never>()

    statePublisher.sink { completion in
      XCTFail()
    } receiveValue: { state in
      XCTFail()
    }
    .store(in: &cancellables)

    Task.detached {
      try? await Task.sleep(nanoseconds: 500_000_000)
      self.dependencyContainer.configManager.configState.send(.retrieved(.stub()))
    }

    Task {
      do {
        try await Superwall.shared.waitForSubsStatusAndConfig(
          stub,
          paywallStatePublisher: statePublisher,
          dependencyContainer: dependencyContainer
        )
        expectation1.fulfill()
      } catch {
        XCTFail()
      }
    }

    wait(for: [expectation1], timeout: 1.1)
  }

  func test_waitForSubsStatusAndConfig_noIdentity_activeStatus_hasConfig() async {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()

    dependencyContainer.configManager.configState.send(.retrieved(.stub()))
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywall(.stub())
    )
    .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    // Sleep to allow reset to complete, then set identity as false.
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    identityManager.identitySubject.send(false)
    
    Task {
      try await Superwall.shared.waitForSubsStatusAndConfig(request, dependencyContainer: dependencyContainer)
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_inactiveStatus_noConfig() {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywall(.stub())
    )
    .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    Task {
      try await Superwall.shared.waitForSubsStatusAndConfig(request, dependencyContainer: dependencyContainer)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitForSubsStatusAndConfig_inactiveStatus_configFailed() {
    let expectation1 = expectation(description: "Got identity")
    expectation1.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      if case .presentationError(_) = state {
        stateExpectation.fulfill()
      }
    }
    .store(in: &cancellables)

    let error = NetworkError.noInternet
    dependencyContainer.configManager.configState.send(completion: .failure(error))

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywall(.stub())
    )
    .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    Task {
      try await Superwall.shared.waitForSubsStatusAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      expectation1.fulfill()
    }

    wait(for: [expectation1, stateExpectation], timeout: 0.1)
  }

  func test_waitForSubsStatusAndConfig_inactiveStatus_hasConfig_noIdentity() {
    let expectation1 = expectation(description: "Got identity")
    expectation1.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    dependencyContainer.configManager.configState.send(.retrieved(.stub()))

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywall(.stub())
    )
    .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    Task {
      // Sleep to allow reset to complete, then set identity as false.
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      identityManager.identitySubject.send(false)

      try await Superwall.shared.waitForSubsStatusAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      expectation1.fulfill()
    }

    wait(for: [expectation1, stateExpectation], timeout: 0.1)
  }

  func test_waitForSubsStatusAndConfig_inactiveStatus_hasConfig_hasIdentity() {
    let expectation1 = expectation(description: "Got identity")

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    dependencyContainer.configManager.configState.send(.retrieved(.stub()))

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywall(.stub())
    )
    .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    Task {
      // Sleep to allow reset to complete, then set identity as true.
      identityManager.identitySubject.send(true)

      try await Superwall.shared.waitForSubsStatusAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      expectation1.fulfill()
    }

    wait(for: [expectation1, stateExpectation], timeout: 0.1)
  }
}
