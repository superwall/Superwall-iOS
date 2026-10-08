//
//  PaywallMessageHandlerTests.swift
//
//
//  Created by Yusuf Tör on 19/01/2023.
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

@Suite
@MainActor
struct PaywallMessageHandlerTests {
  private func waitForJsHandling(
    in webView: FakeWebView,
    timeoutNanoseconds: UInt64 = 5_000_000_000,
    pollIntervalNanoseconds: UInt64 = 20_000_000
  ) async -> Bool {
    let maxPolls = Int(timeoutNanoseconds / pollIntervalNanoseconds)
    for _ in 0..<maxPolls {
      if webView.willHandleJs {
        return true
      }
      try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }
    return webView.willHandleJs
  }

  /// Decodes the `event_name`s of every `accept64` message passed to the webview.
  private func passedEvents(in webView: FakeWebView) -> [[String: Any]] {
    return webView.evaluatedScripts.flatMap { script -> [[String: Any]] in
      guard
        let start = script.range(of: "accept64('"),
        let end = script.range(of: "')", range: start.upperBound..<script.endIndex),
        let data = Data(base64Encoded: String(script[start.upperBound..<end.lowerBound])),
        let events = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
      else {
        return []
      }
      return events
    }
  }

  private func waitForEvent(
    named name: String,
    in webView: FakeWebView
  ) async -> [String: Any]? {
    for _ in 0..<250 {
      if let event = passedEvents(in: webView).first(where: { $0["event_name"] as? String == name }) {
        return event
      }
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return nil
  }

  private func makeHandler() -> (PaywallMessageHandler, FakeWebView, PaywallMessageHandlerDelegateMock) {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    return (messageHandler, webView, delegate)
  }

  // The paywall attributes purchases it starts (web checkouts, teleports) to how it was presented.
  @Test
  func paywallOpen_sendsThePresentation() async {
    let (messageHandler, webView, delegate) = makeHandler()
    delegate.paywall.paywalljsVersion = "2"

    messageHandler.handle(.paywallOpen)

    let open = await waitForEvent(named: "paywall_open", in: webView)
    #expect(open?["presented_by"] as? String == "programmatically")
    #expect(open?["presentation_source_type"] as? String == "register")
    #expect(open?["presentation_id"] == nil)
    #expect(open?["presented_by_event_id"] == nil)
  }

  // Regression: the paywall schedules its trial reminder off `freeTrial_start`, so a purchase
  // that didn't start a trial (e.g. the user already used it) must not send that message.
  @Test
  func transactionComplete_withoutTrial_doesNotSendFreeTrialStart() async {
    let (messageHandler, webView, delegate) = makeHandler()

    messageHandler.handle(
      .transactionComplete(
        trialEndDate: nil,
        productIdentifier: "product1",
        didStartFreeTrial: false
      )
    )

    let complete = await waitForEvent(named: "transaction_complete", in: webView)
    #expect(complete?["product_identifier"] as? String == "product1")

    // transaction_complete is sent first in the same task, so give freeTrial_start a
    // chance to arrive before asserting it never did.
    try? await Task.sleep(nanoseconds: 300_000_000)
    let names = passedEvents(in: webView).compactMap { $0["event_name"] as? String }
    #expect(!names.contains("freeTrial_start"))

    // The handler's delegate is weak and the webview is reached through it, so the
    // mock has to outlive the waits above.
    withExtendedLifetime(delegate) {}
  }

  @Test
  func transactionComplete_withTrial_sendsFreeTrialStartWithEndDate() async {
    let (messageHandler, webView, delegate) = makeHandler()
    let trialEndDate = Date(timeIntervalSince1970: 1_800_000_000)

    messageHandler.handle(
      .transactionComplete(
        trialEndDate: trialEndDate,
        productIdentifier: "product1",
        didStartFreeTrial: true
      )
    )

    let complete = await waitForEvent(named: "transaction_complete", in: webView)
    #expect(complete != nil)

    let freeTrialStart = await waitForEvent(named: "freeTrial_start", in: webView)
    #expect(freeTrialStart?["product_identifier"] as? String == "product1")
    #expect(freeTrialStart?["trial_end_date"] as? Int == 1_800_000_000_000)

    withExtendedLifetime(delegate) {}
  }

  @Test
  func handleTemplateParams() async {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    messageHandler.handle(.templateParamsAndUserAttributes)

    let didHandleJs = await waitForJsHandling(in: webView)
    #expect(didHandleJs == true)
  }

  @Test
  func onReady() async {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    messageHandler.handle(.onReady(paywallJsVersion: "2"))

    let didHandleJs = await waitForJsHandling(in: webView)
    #expect(delegate.paywall.paywalljsVersion == "2")
    #expect(didHandleJs == true)
  }

  @Test
  func close() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    messageHandler.handle(.close)

    #expect(delegate.eventDidOccur == .closed)
  }

  @Test
  func openUrl() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    let url = URL(string: "https://www.google.com")!
    messageHandler.handle(.openUrl(url))

    #expect(delegate.eventDidOccur == .openedURL(url: url))
    #expect(delegate.didPresentSafariInApp == true)
  }

  @Test
  func openUrlInSafari() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    let url = URL(string: "https://www.google.com")!
    messageHandler.handle(.openUrlInSafari(url))

    #expect(delegate.eventDidOccur == .openedUrlInSafari(url))
    #expect(delegate.didPresentSafariExternal == true)
  }

  @Test
  func openUrlInSafari_forcesSafariWhenAsked() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    let url = URL(string: "https://example.com/sw-teleport/abc")!
    messageHandler.handle(.openUrlInSafari(url, drawsWaitingScreen: true))

    #expect(delegate.didPresentSafariExternal == true)
    #expect(delegate.didDrawWaitingScreen == true)
  }

  @Test(arguments: [true, false])
  func openUrlInSafari_tracksTeleportOpenOnlyForTeleports(isTeleport: Bool) async {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    var tracked: [Trackable] = []
    messageHandler.trackEvent = { tracked.append($0) }

    let url = URL(string: "https://example.com/sw-teleport/abc?token=secret#ref=primary")!
    messageHandler.handle(.openUrlInSafari(url, isTeleport: isTeleport))

    for _ in 0..<15 where tracked.isEmpty {
      try? await Task.sleep(nanoseconds: 20_000_000)
    }

    #expect(delegate.didPresentSafariExternal == true)
    guard isTeleport else {
      #expect(tracked.isEmpty)
      return
    }
    #expect(tracked.count == 1)
    let event = tracked.first as? InternalSuperwallEvent.TeleportOpen
    #expect(event?.superwallEvent.description == "teleport_open")
    #expect(event?.paywallInfo.databaseId == delegate.info.databaseId)
    let params = await event?.getSuperwallParameters()
    #expect(params?["url"] == nil)
    #expect(params?["paywall_id"] as? String == delegate.info.databaseId)
  }

  @Test
  func openDeepLink_regularDeepLink_shouldDismiss() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate

    let url = URL(string: "exampleapp://foo")!
    messageHandler.handle(.openDeepLink(url: url))

    #expect(delegate.didOpenDeepLink == true)
    #expect(delegate.deepLinkShouldDismiss == true)
  }

  @Test
  func openDeepLink_superwallDeepLink_withoutRedemption_shouldDismiss() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate

    let url = URL(string: "https://example.superwall.app/app-link/myapp/home")!
    messageHandler.handle(.openDeepLink(url: url))

    #expect(delegate.didOpenDeepLink == true)
    #expect(delegate.deepLinkShouldDismiss == true)
  }

  @Test
  func openDeepLink_redemptionLink_shouldNotDismiss() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate

    let url = URL(string: "exampleapp://superwall/redeem?code=redemption_12345")!
    messageHandler.handle(.openDeepLink(url: url))

    #expect(delegate.didOpenDeepLink == true)
    #expect(delegate.deepLinkShouldDismiss == false)
  }

  @Test
  func restore() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    messageHandler.handle(.restore)

    #expect(delegate.eventDidOccur == .initiateRestore)
  }

  @Test
  func purchaseProduct() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    let productId = "abc"
    messageHandler.handle(.purchase(productId: productId, shouldDismiss: true))

    #expect(delegate.eventDidOccur == .initiatePurchase(
      productId: productId,
      shouldDismiss: true
    ))
  }

  @Test
  func custom() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    let string = "abc"
    messageHandler.handle(.custom(data: string))

    #expect(delegate.eventDidOccur == .custom(string: string))
  }

  @Test
  func userAttributesUpdated() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    let attributes = JSON(["name": "John", "age": 30])
    messageHandler.handle(.userAttributesUpdated(attributes: attributes))

    #expect(delegate.eventDidOccur == .userAttributesUpdated(attributes: attributes))
  }

  @Test
  func requestPermission() async {
    let dependencyContainer = DependencyContainer()
    let fakePermissions = FakePermissionHandler()
    fakePermissions.permissionToReturn = .granted

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: fakePermissions,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate
    let permissionType = PermissionType.notification
    let requestId = "test-request-123"

    messageHandler.handle(.requestPermission(permissionType: permissionType, requestId: requestId))

    let didHandleJs = await waitForJsHandling(in: webView)

    #expect(fakePermissions.requestedPermissions == [.notification])
    #expect(didHandleJs == true) // Should have sent permission_result back
  }

  @Test
  func requestPermission_denied() async {
    let dependencyContainer = DependencyContainer()
    let fakePermissions = FakePermissionHandler()
    fakePermissions.permissionToReturn = .denied

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: fakePermissions,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate

    messageHandler.handle(.requestPermission(permissionType: .notification, requestId: "test-456"))

    let didHandleJs = await waitForJsHandling(in: webView)

    #expect(fakePermissions.requestedPermissions == [.notification])
    #expect(didHandleJs == true) // Should have sent permission_result back
  }

  // MARK: - Purchase Message Decoding Tests

  @Test
  func decodePurchase_noShouldDismiss_defaultsToTrue() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "eventName": "purchase",
            "productIdentifier": "com.test.product"
          }
        ]
      }
    }
    """
    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    let message = wrapped.payload.messages.first

    #expect(message == .purchase(
      productId: "com.test.product",
      shouldDismiss: true
    ))
  }

  @Test
  func decodePurchase_shouldDismissFalse() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "eventName": "purchase",
            "productIdentifier": "com.test.product",
            "should_dismiss": false
          }
        ]
      }
    }
    """
    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    let message = wrapped.payload.messages.first

    #expect(message == .purchase(
      productId: "com.test.product",
      shouldDismiss: false
    ))
  }

  @Test
  func decodePurchase_shouldDismissTrue() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "eventName": "purchase",
            "productIdentifier": "com.test.product",
            "should_dismiss": true
          }
        ]
      }
    }
    """
    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    let message = wrapped.payload.messages.first

    #expect(message == .purchase(
      productId: "com.test.product",
      shouldDismiss: true
    ))
  }

  // MARK: - Open URL External Decoding Tests

  @Test(arguments: [
    (nil, false),
    (false, false),
    (true, true),
  ] as [(Bool?, Bool)])
  func decodeOpenUrlExternal_waitingScreen(waitingScreen: Bool?, draws: Bool) throws {
    let field = waitingScreen.map { ", \"waiting_screen\": \($0)" } ?? ""
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "eventName": "open_url_external",
            "url": "https://example.com/sw-teleport/abc"\(field)
          }
        ]
      }
    }
    """
    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)

    #expect(wrapped.payload.messages.first == .openUrlInSafari(
      URL(string: "https://example.com/sw-teleport/abc")!,
      drawsWaitingScreen: draws
    ))
  }

  @Test(arguments: [
    (nil, false),
    (false, false),
    (true, true),
  ] as [(Bool?, Bool)])
  func decodeOpenUrlExternal_teleport(teleport: Bool?, isTeleport: Bool) throws {
    let field = teleport.map { ", \"teleport\": \($0)" } ?? ""
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "eventName": "open_url_external",
            "url": "https://example.com/sw-teleport/abc",
            "waiting_screen": true\(field)
          }
        ]
      }
    }
    """
    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)

    #expect(wrapped.payload.messages.first == .openUrlInSafari(
      URL(string: "https://example.com/sw-teleport/abc")!,
      drawsWaitingScreen: true,
      isTeleport: isTeleport
    ))
  }

  @Test
  func decodeTeleportWatch() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "eventName": "teleport_watch_start",
            "teleport_id": "v1:teleport",
            "teleport_status_url": "https://subs.example.com/teleport/status",
            "checkout_status_url": "https://subs.example.com/checkout/status",
            "public_api_key": "pk_test"
          },
          { "eventName": "teleport_watch_end" }
        ]
      }
    }
    """
    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)

    #expect(wrapped.payload.messages == [
      .teleportWatchStart(
        TeleportReturnCover.Watch(
          teleportId: "v1:teleport",
          teleportStatusUrl: URL(string: "https://subs.example.com/teleport/status")!,
          checkoutStatusUrl: URL(string: "https://subs.example.com/checkout/status")!,
          publicApiKey: "pk_test"
        )
      ),
      .teleportWatchEnd,
    ])
  }

  // MARK: - Haptic Feedback Message Decoding Tests

  @Test
  func decodeHapticFeedback_medium() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "event_name": "haptic_feedback",
            "haptic_type": "medium"
          }
        ]
      }
    }
    """
    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    let message = wrapped.payload.messages.first

    #expect(message == .hapticFeedback(hapticType: "medium"))
  }

  @Test
  func decodeHapticFeedback_allTypes() throws {
    let hapticTypes = ["light", "medium", "heavy", "success", "warning", "error", "selection"]

    for hapticType in hapticTypes {
      let json = """
      {
        "version": 1,
        "payload": {
          "events": [
            {
              "event_name": "haptic_feedback",
              "haptic_type": "\(hapticType)"
            }
          ]
        }
      }
      """
      let data = json.data(using: .utf8)!
      let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
      let message = wrapped.payload.messages.first

      #expect(message == .hapticFeedback(hapticType: hapticType))
    }
  }

  @Test
  func handleHapticFeedback() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate

    // This should not crash and should not trigger any delegate events
    messageHandler.handle(.hapticFeedback(hapticType: "medium"))

    // Haptic feedback doesn't trigger delegate events, so we just verify it doesn't crash
    #expect(delegate.eventDidOccur == nil)
  }

  @Test
  func decodeStripeCheckoutStart() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "event_name": "stripe_checkout_start",
            "checkout_context_id": "ctx_123",
            "product_identifier": "prod_123"
          }
        ]
      }
    }
    """

    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    let message = wrapped.payload.messages.first

    #expect(message == .stripeCheckoutStart(checkoutContextId: "ctx_123", productId: "prod_123"))
  }

  @Test
  func decodeStripeCheckoutComplete() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "event_name": "stripe_checkout_complete",
            "sw_checkout_id": "sw_123",
            "checkout_context_id": "ctx_123",
            "product_identifier": "prod_123"
          }
        ]
      }
    }
    """

    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    let message = wrapped.payload.messages.first

    #expect(message == .stripeCheckoutComplete(
      checkoutContextId: "ctx_123",
      productId: "prod_123",
      shouldDismiss: nil
    ))
  }

  @Test(arguments: [true, false])
  func decodeStripeCheckoutComplete_withShouldDismiss(shouldDismiss: Bool) throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "event_name": "stripe_checkout_complete",
            "checkout_context_id": "ctx_123",
            "product_identifier": "prod_123",
            "should_dismiss": \(shouldDismiss)
          }
        ]
      }
    }
    """

    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)

    #expect(wrapped.payload.messages.first == .stripeCheckoutComplete(
      checkoutContextId: "ctx_123",
      productId: "prod_123",
      shouldDismiss: shouldDismiss
    ))
  }

  @Test
  func decodeStripeCheckoutFail() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "event_name": "stripe_checkout_fail",
            "checkout_context_id": "ctx_123",
            "product_identifier": "prod_123"
          }
        ]
      }
    }
    """

    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    let message = wrapped.payload.messages.first

    #expect(message == .stripeCheckoutFail(checkoutContextId: "ctx_123", productId: "prod_123"))
  }

  @Test
  func decodeStripeCheckoutSubmit() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "event_name": "stripe_checkout_submit",
            "checkout_context_id": "ctx_123",
            "product_identifier": "prod_123"
          }
        ]
      }
    }
    """

    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    let message = wrapped.payload.messages.first

    #expect(message == .stripeCheckoutSubmit(checkoutContextId: "ctx_123", productId: "prod_123"))
  }

  @Test
  func decodeStripeCheckoutAbandon() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "event_name": "stripe_checkout_abandon",
            "checkout_context_id": "ctx_123",
            "product_identifier": "prod_123"
          }
        ]
      }
    }
    """

    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    let message = wrapped.payload.messages.first

    #expect(message == .stripeCheckoutAbandon(checkoutContextId: "ctx_123", productId: "prod_123"))
  }

  @Test
  func handleStripeCheckoutComplete_forwardsToDelegate() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate

    messageHandler.handle(
      .stripeCheckoutComplete(
        checkoutContextId: "ctx_123",
        productId: "prod_123",
        shouldDismiss: false
      )
    )

    #expect(delegate.stripeCheckoutComplete?.checkoutContextId == "ctx_123")
    #expect(delegate.stripeCheckoutComplete?.productId == "prod_123")
    #expect(delegate.stripeCheckoutCompleteShouldDismiss == false)
  }

  @Test
  func handleStripeCheckoutAbandon_forwardsToDelegate() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate

    messageHandler.handle(.stripeCheckoutAbandon(checkoutContextId: "ctx_123", productId: "prod_123"))

    #expect(delegate.stripeCheckoutAbandon?.checkoutContextId == "ctx_123")
    #expect(delegate.stripeCheckoutAbandon?.productId == "prod_123")
  }

  @Test
  func handleStripeCheckoutFail_isNoOp() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate

    messageHandler.handle(.stripeCheckoutFail(checkoutContextId: "ctx_123", productId: "prod_123"))

    #expect(delegate.stripeCheckoutSubmit == nil)
    #expect(delegate.stripeCheckoutComplete == nil)
    #expect(delegate.stripeCheckoutAbandon == nil)
    #expect(delegate.eventDidOccur == nil)
  }

  @Test
  func handleStripeCheckoutSubmit_forwardsToDelegate() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = FakeWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let delegate = PaywallMessageHandlerDelegateMock(
      paywallInfo: .stub(),
      webView: webView
    )
    messageHandler.delegate = delegate

    messageHandler.handle(.stripeCheckoutSubmit(checkoutContextId: "ctx_123", productId: "prod_123"))

    #expect(delegate.stripeCheckoutSubmit?.checkoutContextId == "ctx_123")
    #expect(delegate.stripeCheckoutSubmit?.productId == "prod_123")
  }
}
