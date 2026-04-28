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

  // MARK: - Headers

  @Test func headers_xEntitlements_isCommaSeparatedString() async {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    let entitlements: Set<Entitlement> = [
      Entitlement(id: "pro"),
      Entitlement(id: "premium"),
      Entitlement(id: "gold")
    ]
    superwall.subscriptionStatus = .active(entitlements)

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let headers = await dependencyContainer.makeHeaders(
      fromRequest: request,
      isForDebugging: false,
      requestId: "test-request-id"
    )

    let entitlementsHeader = headers["X-Entitlements"] ?? ""
    let headerIds = Set(entitlementsHeader.split(separator: ",").map(String.init))
    #expect(headerIds == Set(["pro", "premium", "gold"]))
  }

  @Test func headers_xEntitlements_emptyWhenNoActiveEntitlements() async {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    superwall.subscriptionStatus = .inactive

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let headers = await dependencyContainer.makeHeaders(
      fromRequest: request,
      isForDebugging: false,
      requestId: "test-request-id"
    )

    let entitlementsHeader = headers["X-Entitlements"]
    #expect(entitlementsHeader == "")
  }

  @Test func headers_xEntitlements_singleEntitlement() async {
    let dependencyContainer = DependencyContainer()
    let superwall = Superwall(dependencyContainer: dependencyContainer)

    superwall.subscriptionStatus = .active([Entitlement(id: "pro")])

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let headers = await dependencyContainer.makeHeaders(
      fromRequest: request,
      isForDebugging: false,
      requestId: "test-request-id"
    )

    #expect(headers["X-Entitlements"] == "pro")
  }

  @Test func pollRedemptionResult_endpointBuildsRequest() async throws {
    let dependencyContainer = DependencyContainer()
    let request = PollRedemptionResultRequest(
      checkoutContextId: "ctx_123",
      deviceId: "device_123",
      appUserId: "user_123"
    )
    let endpoint = Endpoint<EndpointKinds.SubscriptionsAPI, RedeemResponse>.pollRedemptionResult(request: request)

    let urlRequest = await endpoint.makeRequest(
      with: SuperwallRequestData(factory: dependencyContainer),
      factory: dependencyContainer
    )

    #expect(urlRequest?.httpMethod == "POST")
    #expect(
      urlRequest?.url?.absoluteString.contains(
        "/subscriptions-api/public/v1/checkout/session/poll-redemption-result"
      ) == true
    )

    let bodyData = try #require(urlRequest?.httpBody)
    let bodyJson = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
    #expect(bodyJson["checkoutContextId"] as? String == "ctx_123")
    #expect(bodyJson["deviceId"] as? String == "device_123")
    #expect(bodyJson["appUserId"] as? String == "user_123")
  }
}
