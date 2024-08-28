//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

@available(iOS 16.0, *)
final class WaitForEntitlementsAndConfigTests: XCTestCase {
  var cancellables: [AnyCancellable] = []
  let dependencyContainer = DependencyContainer()
  var identityManager: IdentityManager {
    return dependencyContainer.identityManager
  }
  
  override func setUp() async throws {
    identityManager.reset(duringIdentify: false)
  }

  func test_waitForEntitlementsAndConfig_noIdentity_hasNotSetActiveEntitlements() async {
    let expectation1 = expectation(description: "Got identity")

    let falsePublisher = CurrentValueSubject<Bool, Never>(false)
      .eraseToAnyPublisher()
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: falsePublisher)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    do {
      try await Superwall.shared.waitForEntitlementsAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
    } catch {
      expectation1.fulfill()
    }

    await fulfillment(of: [expectation1, stateExpectation], timeout: 5.5)
  }

  func test_waitForEntitlementsAndConfig_noIdentity_delayedActiveEntitlements_hasEntitlements_hasConfig() async {
    let expectation1 = expectation(description: "Got identity")
    expectation1.isInverted = true

    let entitlementsInfo = EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: true
    )
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: entitlementsInfo.$didSetActiveEntitlements.eraseToAnyPublisher())
      .setting(\.flags.entitlements, to: entitlementsInfo)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    Task {
      do {
        try await Superwall.shared.waitForEntitlementsAndConfig(
          request,
          paywallStatePublisher: statePublisher,
          dependencyContainer: dependencyContainer
        )
      } catch {
        expectation1.fulfill()
      }
    }

    try? await Task.sleep(for: .seconds(1))

    dependencyContainer.configManager.configState.send(.retrieved(.stub()))
    entitlementsInfo.set([.stub()])

    await fulfillment(of: [expectation1, stateExpectation], timeout: 5.5)
  }

  func test_waitForEntitlementsAndConfig_hasEntitlements_noConfigEvenAfterDelay() async {
    let expectation1 = expectation(description: "Got identity")

    let entitlementsInfo = EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: true
    )
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: entitlementsInfo.$didSetActiveEntitlements.eraseToAnyPublisher())
      .setting(\.flags.entitlements, to: entitlementsInfo)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      stateExpectation.fulfill()
    } receiveValue: { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    entitlementsInfo.set([.stub()])

    do {
      try await Superwall.shared.waitForEntitlementsAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      XCTFail()
    } catch {
      expectation1.fulfill()
    }

    await fulfillment(of: [expectation1, stateExpectation], timeout: 1.1)
  }

  func test_waitForEntitlementsAndConfig_hasEntitlements_noConfig_configFailedState() async {
    let expectation1 = expectation(description: "Got identity")

    let entitlementsInfo = EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: true
    )
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: entitlementsInfo.$didSetActiveEntitlements.eraseToAnyPublisher())
      .setting(\.flags.entitlements, to: entitlementsInfo)

    entitlementsInfo.set([.stub()])

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

    do {
      try await Superwall.shared.waitForEntitlementsAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      XCTFail()
    } catch {
      expectation1.fulfill()
    }

    await fulfillment(of: [expectation1, stateExpectation], timeout: 0.1)
  }

  func test_waitForEntitlementsAndConfig_hasEntitlements_noConfig_configRetryingState() async {
    let expectation1 = expectation(description: "Got identity")

    let entitlementsInfo = EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: true
    )
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: entitlementsInfo.$didSetActiveEntitlements.eraseToAnyPublisher())
      .setting(\.flags.entitlements, to: entitlementsInfo)

    entitlementsInfo.set([.stub()])

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

    do {
      try await Superwall.shared.waitForEntitlementsAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      XCTFail()
    } catch {
      expectation1.fulfill()
    }

    await fulfillment(of: [expectation1, stateExpectation], timeout: 0.1)
  }

  func test_waitForEntitlementsAndConfig_hasEntitlements_noConfig_hasConfigAfterDelay() async {
    let expectation1 = expectation(description: "Got identity")
    let entitlementsInfo = EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: true
    )
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: entitlementsInfo.$didSetActiveEntitlements.eraseToAnyPublisher())
      .setting(\.flags.entitlements, to: entitlementsInfo)

    entitlementsInfo.set([.stub()])

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

    do {
      try await Superwall.shared.waitForEntitlementsAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      expectation1.fulfill()
    } catch {
      XCTFail()
    }

    await fulfillment(of: [expectation1], timeout: 1.1)
  }

  func test_waitToPresent_noEntitlements_noConfig() {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let entitlementsInfo = EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: true
    )
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: entitlementsInfo.$didSetActiveEntitlements.eraseToAnyPublisher())
      .setting(\.flags.entitlements, to: entitlementsInfo)

    entitlementsInfo.set([])

    Task {
      try await Superwall.shared.waitForEntitlementsAndConfig(request, dependencyContainer: dependencyContainer)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitForEntitlementsAndConfig_inactiveStatus_configFailed() {
    let expectation1 = expectation(description: "Got identity")
    expectation1.isInverted = true

    let entitlementsInfo = EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: true
    )
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: entitlementsInfo.$didSetActiveEntitlements.eraseToAnyPublisher())
      .setting(\.flags.entitlements, to: entitlementsInfo)

    entitlementsInfo.set([])

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

    Task {
      try await Superwall.shared.waitForEntitlementsAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      expectation1.fulfill()
    }

    wait(for: [expectation1, stateExpectation], timeout: 0.1)
  }

  func test_waitForEntitlementsAndConfig_inactiveStatus_hasConfig_noIdentity() {
    let expectation1 = expectation(description: "Got identity")
    expectation1.isInverted = true

    let entitlementsInfo = EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: true
    )
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: entitlementsInfo.$didSetActiveEntitlements.eraseToAnyPublisher())
      .setting(\.flags.entitlements, to: entitlementsInfo)

    entitlementsInfo.set([])

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
    let truePublisher = CurrentValueSubject<Bool, Never>(true)
      .eraseToAnyPublisher()

    Task {
      // Sleep to allow reset to complete, then set identity as false.
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      identityManager.identitySubject.send(false)

      try await Superwall.shared.waitForEntitlementsAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      expectation1.fulfill()
    }

    wait(for: [expectation1, stateExpectation], timeout: 0.1)
  }

  func test_waitForEntitlementsAndConfig_inactiveStatus_hasConfig_hasIdentity() {
    let expectation1 = expectation(description: "Got identity")

    let entitlementsInfo = EntitlementsInfo(
      storage: dependencyContainer.storage,
      delegateAdapter: dependencyContainer.delegateAdapter,
      isTesting: true
    )
    let request = PresentationRequest.stub()
      .setting(\.flags.didSetActiveEntitlements, to: entitlementsInfo.$didSetActiveEntitlements.eraseToAnyPublisher())
      .setting(\.flags.entitlements, to: entitlementsInfo)

    entitlementsInfo.set([])

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

    Task {
      // Sleep to allow reset to complete, then set identity as true.
      identityManager.identitySubject.send(true)

      try await Superwall.shared.waitForEntitlementsAndConfig(
        request,
        paywallStatePublisher: statePublisher,
        dependencyContainer: dependencyContainer
      )
      expectation1.fulfill()
    }

    wait(for: [expectation1, stateExpectation], timeout: 0.1)
  }
}
