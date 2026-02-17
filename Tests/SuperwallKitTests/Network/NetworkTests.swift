//
//  File.swift
//
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

import UIKit
import Testing
import Combine
@testable import SuperwallKit

struct NetworkTests {
  func configWrapper(
    urlSession: CustomURLSessionMock,
    injectedApplicationStatePublisher: AnyPublisher<UIApplication.State, Never>,
    completion: @escaping () -> Void
  ) {
    _ = Task {
      let dependencyContainer = DependencyContainer()
      let network = Network(
        urlSession: urlSession,
        options: SuperwallOptions(),
        factory: dependencyContainer
      )

      _ = try? await network.getConfig(
        injectedApplicationStatePublisher: injectedApplicationStatePublisher,
        maxRetry: 0,
        isRetryingCallback: { _ in }
      )
      completion()
    }
  }

  // MARK: - Config
  @Test func config_inBackground() async {
    let dependencyContainer = DependencyContainer()
    let urlSession = CustomURLSessionMock(factory: dependencyContainer)
    let publisher = CurrentValueSubject<UIApplication.State, Never>(.background)
      .eraseToAnyPublisher()

    var didComplete = false
    configWrapper(
      urlSession: urlSession,
      injectedApplicationStatePublisher: publisher
    ) {
      didComplete = true
    }

    try? await Task.sleep(nanoseconds: 400_000_000)

    #expect(!didComplete)
    #expect(!urlSession.didRequest)
  }

  @Test func config_inForeground() async {
    let dependencyContainer = DependencyContainer()
    let urlSession = CustomURLSessionMock(factory: dependencyContainer)
    let network = Network(
      urlSession: urlSession,
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let publisher = CurrentValueSubject<UIApplication.State, Never>(.active)
      .eraseToAnyPublisher()

    _ = try? await network.getConfig(
      injectedApplicationStatePublisher: publisher,
      maxRetry: 0,
      isRetryingCallback: { _ in }
    )
    #expect(urlSession.didRequest)
  }

  @Test func config_inBackgroundThenForeground() async {
    let dependencyContainer = DependencyContainer()
    let urlSession = CustomURLSessionMock(factory: dependencyContainer)
    let network = Network(
      urlSession: urlSession,
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let publisher = [UIApplication.State.background, UIApplication.State.active]
      .publisher
      .eraseToAnyPublisher()

    _ = try? await network.getConfig(
      injectedApplicationStatePublisher: publisher,
      maxRetry: 0,
      isRetryingCallback: { _ in }
    )
    #expect(urlSession.didRequest)
  }
}
