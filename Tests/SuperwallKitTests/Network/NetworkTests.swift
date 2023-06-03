//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

import XCTest
import Combine
@testable import SuperwallKit

@available(iOS 14.0, *)
final class NetworkTests: XCTestCase {
  func configWrapper(
    urlSession: CustomURLSessionMock,
    injectedApplicationStatePublisher: AnyPublisher<UIApplication.State, Never>,
    completion: @escaping () -> Void
  ) async {
    let task = Task {
      let dependencyContainer = DependencyContainer()
      let network = Network(urlSession: urlSession, factory: dependencyContainer)
      let requestId = "abc"

      _ = try? await network.getConfig(
        injectedApplicationStatePublisher: injectedApplicationStatePublisher,
        isRetryingCallback: {}
      )
      completion()
    }

    let milliseconds = 200
    let nanoseconds = UInt64(milliseconds * 1_000_000)
    try? await Task.sleep(nanoseconds: nanoseconds)

    task.cancel()
  }

  // MARK: - Config
  func test_config_inBackground() async {
    let urlSession = CustomURLSessionMock()
    let publisher = Just(UIApplication.State.background)
      .eraseToAnyPublisher()
    let expectation = expectation(description: "config completed")
    expectation.isInverted = true
    await configWrapper(
      urlSession: urlSession,
      injectedApplicationStatePublisher: publisher
    ) {
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 0.4)

    XCTAssertFalse(urlSession.didRequest)
  }

  func test_config_inForeground() async {
    let urlSession = CustomURLSessionMock()
    let dependencyContainer = DependencyContainer()
    let network = Network(urlSession: urlSession, factory: dependencyContainer)
    let publisher = Just(UIApplication.State.active)
      .eraseToAnyPublisher()

    _ = try? await network.getConfig(
      injectedApplicationStatePublisher: publisher,
      isRetryingCallback: {}
    )
    XCTAssertTrue(urlSession.didRequest)
  }

  func test_config_inBackgroundThenForeground() async {
    let urlSession = CustomURLSessionMock()
    let dependencyContainer = DependencyContainer()
    let network = Network(urlSession: urlSession, factory: dependencyContainer)
    let publisher = [UIApplication.State.background, UIApplication.State.active]
      .publisher
      .eraseToAnyPublisher()

    _ = try? await network.getConfig(
      injectedApplicationStatePublisher: publisher,
      isRetryingCallback: {}
    )
    XCTAssertTrue(urlSession.didRequest)
  }
}
