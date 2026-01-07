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
  @Test
  func handleTemplateParams() async {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler()
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

    try? await Task.sleep(nanoseconds: 1_500_000_000)

    #expect(webView.willHandleJs == true)
  }

  @Test
  func onReady() async {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler()
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

    try? await Task.sleep(nanoseconds: 1_500_000_000)

    #expect(delegate.paywall.paywalljsVersion == "2")
    #expect(webView.willHandleJs == true)
  }

  @Test
  func close() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler()
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
      permissionHandler: FakePermissionHandler()
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
      permissionHandler: FakePermissionHandler()
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
      permissionHandler: FakePermissionHandler()
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
      permissionHandler: FakePermissionHandler()
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
      permissionHandler: FakePermissionHandler()
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
      permissionHandler: FakePermissionHandler()
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
      permissionHandler: FakePermissionHandler()
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
    messageHandler.handle(.purchase(productId: productId))

    #expect(delegate.eventDidOccur == .initiatePurchase(productId: productId))
  }

  @Test
  func custom() {
    let dependencyContainer = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler()
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
      permissionHandler: FakePermissionHandler()
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
      permissionHandler: fakePermissions
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

    // Wait for async task to complete
    try? await Task.sleep(nanoseconds: 1_500_000_000)

    #expect(fakePermissions.requestedPermissions == [.notification])
    #expect(webView.willHandleJs == true) // Should have sent permission_result back
  }

  @Test
  func requestPermission_denied() async {
    let dependencyContainer = DependencyContainer()
    let fakePermissions = FakePermissionHandler()
    fakePermissions.permissionToReturn = .denied

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: fakePermissions
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

    // Wait for async task to complete
    try? await Task.sleep(nanoseconds: 1_500_000_000)

    #expect(fakePermissions.requestedPermissions == [.notification])
    #expect(webView.willHandleJs == true) // Should have sent permission_result back
  }
}
