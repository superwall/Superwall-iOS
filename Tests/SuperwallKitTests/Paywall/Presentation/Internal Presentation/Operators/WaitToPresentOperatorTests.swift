//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class WaitToPresentTests: XCTestCase {
  var cancellables: [AnyCancellable] = []
  let dependencyContainer = DependencyContainer()
  var identityManager: IdentityManager {
    return dependencyContainer.identityManager
  }
  
  override func setUp() async throws {
    identityManager.reset(duringIdentify: false)
  }

  func test_waitToPresent_noIdentity_unknownStatus() {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.unknown)
      .eraseToAnyPublisher()
    let request = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)


    Task {
      try await Superwall.shared.waitToPresent(request, dependencyContainer: dependencyContainer)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_noIdentity_activeStatus() {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let request = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    Task {
      try await Superwall.shared.waitToPresent(request)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_hasIdentity_activeStatus_noConfig() {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let stub = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    Task {
      try await Superwall.shared.waitToPresent(stub, dependencyContainer: dependencyContainer)
      expectation.fulfill()
    }

    identityManager.didSetIdentity()

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_hasIdentity_inactiveStatus_hasConfig() {
    let expectation = expectation(description: "Got identity")

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    dependencyContainer.configManager.config = .stub()
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywallViewController(.stub()),
      hasInternetOverride: true
    )
    .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    Task {
      try await Superwall.shared.waitToPresent(request, dependencyContainer: dependencyContainer)
      expectation.fulfill()
    }

    identityManager.didSetIdentity()

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_hasIdentity_inactiveStatus_hasConfig_noInternet() {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let inactiveSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    dependencyContainer.configManager.config = .stub()
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywallViewController(.stub()),
      hasInternetOverride: false
    )
    .setting(\.flags.subscriptionStatus, to: inactiveSubscriptionPublisher)

    Task {
      do {
        try await Superwall.shared.waitToPresent(request, dependencyContainer: dependencyContainer)
      } catch {
        expectation.fulfill()
      }
    }

    identityManager.didSetIdentity()

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_hasIdentity_inactiveStatus_noConfig_noInternet() {
    let expectation = expectation(description: "Got identity")

    let inactiveSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    dependencyContainer.configManager.config = nil
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywallViewController(.stub()),
      hasInternetOverride: false
    )
    .setting(\.flags.subscriptionStatus, to: inactiveSubscriptionPublisher)

    Task {
      do {
        try await Superwall.shared.waitToPresent(request, dependencyContainer: dependencyContainer)
      } catch let error as PresentationPipelineError {
        if case .noInternet = error {
          expectation.fulfill()
        }
      }
    }

    identityManager.didSetIdentity()

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_hasIdentity_activeStatus_noConfig_noInternet() {
    let expectation = expectation(description: "Got identity")

    let inactiveSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()

    dependencyContainer.configManager.config = nil
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywallViewController(.stub()),
      hasInternetOverride: false
    )
    .setting(\.flags.subscriptionStatus, to: inactiveSubscriptionPublisher)

    Task {
      do {
        try await Superwall.shared.waitToPresent(request, dependencyContainer: dependencyContainer)
      } catch let error as PresentationPipelineError {
        if case .userIsSubscribed = error {
          expectation.fulfill()
        }
      }
    }

    identityManager.didSetIdentity()

    wait(for: [expectation], timeout: 0.1)
  }
}
