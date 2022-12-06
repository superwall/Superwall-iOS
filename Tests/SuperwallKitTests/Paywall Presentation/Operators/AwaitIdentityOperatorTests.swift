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

  override func setUp() async throws {
    IdentityManager.shared.reset()
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

    IdentityManager.shared.didSetIdentity()

    wait(for: [expectation], timeout: 0.1)
  }
}
