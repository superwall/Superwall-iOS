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
  ) {
    _ = Task {
      let dependencyContainer = DependencyContainer()
      let network = Network(urlSession: urlSession, options: SuperwallOptions(), factory: dependencyContainer)

      _ = try? await network.getConfig(
        injectedApplicationStatePublisher: injectedApplicationStatePublisher,
        isRetryingCallback: { _ in }
      )
      completion()
    }
  }

  // MARK: - Config
  func test_config_inBackground() async {
    let dependencyContainer = DependencyContainer()
    let urlSession = CustomURLSessionMock(factory: dependencyContainer)
    let publisher = CurrentValueSubject<UIApplication.State, Never>(.background)
      .eraseToAnyPublisher()
    let expectation = expectation(description: "config completed")
    expectation.isInverted = true
    configWrapper(
      urlSession: urlSession,
      injectedApplicationStatePublisher: publisher
    ) {
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 0.4)

    XCTAssertFalse(urlSession.didRequest)
  }

  func test_config_inForeground() async {
    let dependencyContainer = DependencyContainer()
    let urlSession = CustomURLSessionMock(factory: dependencyContainer)
    let network = Network(urlSession: urlSession, options: SuperwallOptions(), factory: dependencyContainer)
    let publisher = CurrentValueSubject<UIApplication.State, Never>(.active)
      .eraseToAnyPublisher()

    _ = try? await network.getConfig(
      injectedApplicationStatePublisher: publisher,
      isRetryingCallback: { _ in }
    )
    XCTAssertTrue(urlSession.didRequest)
  }

  func test_config_inBackgroundThenForeground() async {
    let dependencyContainer = DependencyContainer()
    let urlSession = CustomURLSessionMock(factory: dependencyContainer)
    let network = Network(urlSession: urlSession, options: SuperwallOptions(), factory: dependencyContainer)
    let publisher = [UIApplication.State.background, UIApplication.State.active]
      .publisher
      .eraseToAnyPublisher()

    _ = try? await network.getConfig(
      injectedApplicationStatePublisher: publisher,
      isRetryingCallback: { _ in }
    )
    XCTAssertTrue(urlSession.didRequest)
  }
}
