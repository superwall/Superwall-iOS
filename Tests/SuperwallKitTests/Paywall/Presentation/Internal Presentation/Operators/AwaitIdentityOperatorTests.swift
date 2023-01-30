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
  let identityManager: IdentityManager = {
    let dependencyContainer = DependencyContainer()
    return dependencyContainer.identityManager
  }()
  
  override func setUp() async throws {
    identityManager.reset()
  }

  func test_waitingForIdentity_noIdentity() async {
    let expectation = expectation(description: "Got identity")
    expectation.isInverted = true

    CurrentValueSubject(PresentationRequest.stub())
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .awaitIdentity()
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

  func test_waitingForIdentity_hasIdentity() async {
    let expectation = expectation(description: "Got identity")

    let stub = PresentationRequest.stub()
      .setting(\.dependencyContainer.identityManager, to: identityManager)

    CurrentValueSubject(stub)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .awaitIdentity()
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
