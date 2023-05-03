//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/01/2023.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit
import Combine

final class CheckPaywallIsPresentableTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_checkPaywallIsPresentable_userIsSubscribed() async {
    let expectation = expectation(description: "Did throw")

    let dependencyContainer = DependencyContainer()
    let publisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.active)
      .eraseToAnyPublisher()
    let paywallVcPipelineOutput = await PaywallVcPipelineOutput(
      request: .stub()
        .setting(\.flags.subscriptionStatus, to: publisher),
      triggerResult: .paywall(.stub()),
      debugInfo: [:],
      paywallViewController: dependencyContainer.makePaywallViewController(for: .stub(), withCache: nil),
      confirmableAssignment: nil
    )

    CurrentValueSubject(paywallVcPipelineOutput)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkPaywallIsPresentable()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            guard let error = error as? GetPresentationResultError else {
              return XCTFail("Wrong type of error")
            }
            XCTAssertEqual(error, .userIsSubscribed)
            expectation.fulfill()
          case .finished:
            XCTFail("Shouldn't have finished")
          }
        },
        receiveValue: { _ in }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 100_000_000)

    wait(for: [expectation], timeout: 0.1)
  }

  func test_checkPaywallIsPresentable_userNotSubscribed() async {
    let expectation = expectation(description: "Did throw")

    let dependencyContainer = DependencyContainer()
    let triggerResult: TriggerResult = .paywall(.stub())

    let publisher = CurrentValueSubject<SubscriptionStatus, Never>(SubscriptionStatus.inactive)
      .eraseToAnyPublisher()

    let paywallVcPipelineOutput = await PaywallVcPipelineOutput(
      request: .stub()
        .setting(\.flags.subscriptionStatus, to: publisher),
      triggerResult: triggerResult,
      debugInfo: [:],
      paywallViewController: dependencyContainer.makePaywallViewController(for: .stub(), withCache: nil),
      confirmableAssignment: nil
    )

    CurrentValueSubject(paywallVcPipelineOutput)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkPaywallIsPresentable()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          XCTFail("Shouldn't have finished")
        },
        receiveValue: { result in
          XCTAssertEqual(result, triggerResult)
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    try? await Task.sleep(nanoseconds: 100_000_000)

    wait(for: [expectation], timeout: 0.1)
  }
}
