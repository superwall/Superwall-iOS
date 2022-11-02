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
      let network = Network(urlSession: urlSession)
      let configManager = ConfigManager()
      let requestId = "abc"

      _ = try? await network.getConfig(
        withRequestId: requestId,
        configManager: configManager,
        injectedApplicationStatePublisher: injectedApplicationStatePublisher
      )
      completion()
    }

    let twoHundredMilliseconds = UInt64(200_000_000)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)

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

    wait(for: [expectation], timeout: 0.4)
    XCTAssertFalse(urlSession.didRequest)
  }

  func test_config_inForeground() async {
    let urlSession = CustomURLSessionMock()
    let network = Network(urlSession: urlSession)
    let configManager = ConfigManager()
    let requestId = "abc"
    let publisher = Just(UIApplication.State.active)
      .eraseToAnyPublisher()

    _ = try? await network.getConfig(
      withRequestId: requestId,
      configManager: configManager,
      injectedApplicationStatePublisher: publisher
    )
    XCTAssertTrue(urlSession.didRequest)
  }
}
