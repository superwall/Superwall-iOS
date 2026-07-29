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

  @Test func resolvePaywall_endpointBuildsRequest() async throws {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.debugKey = "sat_test"
    let endpoint = Endpoint<EndpointKinds.Superwall, PaywallIdentifierResolution>.resolvePaywall(
      byDatabaseId: "123",
      retryCount: 6
    )

    let urlRequest = await endpoint.makeRequest(
      with: SuperwallRequestData(factory: dependencyContainer, isForDebugging: true),
      factory: dependencyContainer
    )

    #expect(urlRequest?.httpMethod == "GET")

    let urlString = try #require(urlRequest?.url?.absoluteString)
    // Host and path asserted together: matching the path alone passes whichever
    // host the endpoint resolved to, which is how the V2 resolver shipped
    // pointing at the v1 `baseHost` (fixed in b073dda).
    #expect(urlString.contains("api.superwall.com/v2/paywalls/resolve"))
    #expect(urlString.contains("id=123"))

    // The resolver authenticates with the debugger's signed preview token
    // (isForDebugging: true), so the Authorization header carries the
    // `sat_` debug key as a bearer token, not the app's public key.
    #expect(urlRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer sat_test")
  }

  @Test func listPreviewPaywalls_endpointBuildsRequest() async throws {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.debugKey = "sat_test"
    let endpoint = Endpoint<EndpointKinds.Superwall, PaywallPreviewList>.listPreviewPaywalls(
      retryCount: 2
    )

    let urlRequest = await endpoint.makeRequest(
      with: SuperwallRequestData(factory: dependencyContainer, isForDebugging: true),
      factory: dependencyContainer
    )

    #expect(urlRequest?.httpMethod == "GET")

    let urlString = try #require(urlRequest?.url?.absoluteString)
    // Host included for the same reason as the resolver's test: the path alone
    // would pass against the v1 `baseHost`.
    #expect(urlString.contains("api.superwall.com/v2/paywalls/preview-list"))

    // The application comes from the token's scope server-side, so the picker
    // must not be sending an id or application_id of its own.
    #expect(urlString.contains("?") == false)

    // Same auth as the resolver: the debugger's `sat_` preview token as a
    // bearer, not the app's public key.
    #expect(urlRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer sat_test")
  }

  @Test func paywallPreviewList_decodesIgnoringUndeclaredFields() throws {
    // `object`, `has_more` and `application_id` are returned by the endpoint but
    // deliberately not declared on the model. Decoding must ignore them rather
    // than throw, so a change to those fields can never empty the picker.
    let json = """
    {
      "object": "list",
      "has_more": false,
      "application_id": "2889",
      "data": [
        { "id": "178725", "identifier": "some-slug", "name": "Some Paywall" }
      ]
    }
    """.data(using: .utf8)!

    let list = try JSONDecoder.fromSnakeCase.decode(PaywallPreviewList.self, from: json)

    #expect(list.data.count == 1)
    #expect(list.data.first?.id == "178725")
    #expect(list.data.first?.identifier == "some-slug")
    #expect(list.data.first?.name == "Some Paywall")
  }

  @Test func paywallPreviewList_decodesWhenUndeclaredFieldsAbsent() throws {
    // The inverse: `data` alone must decode, so the picker survives the endpoint
    // dropping fields the SDK never reads.
    let json = """
    { "data": [{ "id": "1", "identifier": "s", "name": "N" }] }
    """.data(using: .utf8)!

    let list = try JSONDecoder.fromSnakeCase.decode(PaywallPreviewList.self, from: json)

    #expect(list.data.count == 1)
  }

  @Test func paywallPreviewList_decodesEmptyList() throws {
    // An app with no previewable paywalls returns an empty `data`. That must
    // decode cleanly — `pressedPreview` then declines to open the picker rather
    // than the request being treated as a failure.
    let json = """
    { "object": "list", "has_more": false, "data": [] }
    """.data(using: .utf8)!

    let list = try JSONDecoder.fromSnakeCase.decode(PaywallPreviewList.self, from: json)

    #expect(list.data.isEmpty)
  }
}
