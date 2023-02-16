//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class AwaitIdentityOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []
  let dependencyContainer = DependencyContainer()
  var identityManager: IdentityManager {
    return dependencyContainer.identityManager
  }
  
  override func setUp() async throws {
    identityManager.reset()
  }

  func test_waitToPresent_noIdentity_unknownStatus() async {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.unknown)
      .eraseToAnyPublisher()
    let request = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    CurrentValueSubject(request)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .waitToPresent()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_noIdentity_activeStatus() async {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let request = PresentationRequest.stub()
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    CurrentValueSubject(request)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .waitToPresent()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_hasIdentity_activeStatus_noConfig() async {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let stub = PresentationRequest.stub()
      .setting(\.dependencyContainer.identityManager, to: identityManager)
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    CurrentValueSubject(stub)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .waitToPresent()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    identityManager.didSetIdentity()

    wait(for: [expectation], timeout: 0.1)
  }

  func test_waitToPresent_hasIdentity_activeStatus_hasConfig() async {
    let expectation = expectation(description: "Got identity")

    let unknownSubscriptionPublisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()

    let stub = PresentationRequest.stub()
      .setting(\.dependencyContainer.identityManager, to: identityManager)
      .setting(\.dependencyContainer.configManager, to: configManager)
      .setting(\.flags.subscriptionStatus, to: unknownSubscriptionPublisher)

    CurrentValueSubject(stub)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .waitToPresent()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    identityManager.didSetIdentity()

    wait(for: [expectation], timeout: 0.1)
  }
}
