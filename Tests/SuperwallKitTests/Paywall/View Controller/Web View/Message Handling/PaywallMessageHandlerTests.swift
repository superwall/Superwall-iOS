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
      productId: "prod_123"
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
        productId: "prod_123"
      )
    )

    #expect(delegate.stripeCheckoutComplete?.checkoutContextId == "ctx_123")
    #expect(delegate.stripeCheckoutComplete?.productId == "prod_123")
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
