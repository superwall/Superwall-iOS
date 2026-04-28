//
//  CustomCallbackRegistryTests.swift
//
//
//  Created by Yusuf Tör on 22/04/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite
@MainActor
struct CustomCallbackGetPaywallTests {
  private func makePaywallVc(
    paywall: Paywall,
    delegate: PaywallViewControllerDelegateAdapter?,
    in dependencyContainer: DependencyContainer
  ) -> PaywallViewControllerMock {
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    return PaywallViewControllerMock(
      paywall: paywall,
      delegate: delegate,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
  }

  @Test
  func customCallbackHandlerIsRegisteredWhenAdapterHasHandler() async {
    let dependencyContainer = DependencyContainer()
    let paywall = Paywall.stub()
      .setting(\.identifier, to: "paywall_register_test")

    let adapter = PaywallViewControllerDelegateAdapter(
      swiftDelegate: nil,
      objcDelegate: nil,
      onCustomCallback: { callback in
        return .success(data: ["echo": callback.name])
      }
    )

    let paywallVc = makePaywallVc(paywall: paywall, delegate: adapter, in: dependencyContainer)

    let registered = dependencyContainer.customCallbackRegistry.getHandler(
      paywallIdentifier: paywall.identifier
    )
    #expect(registered != nil)

    let result = await registered?(CustomCallback(name: "ping", variables: nil))
    #expect(result?.status == .success)
    #expect(result?.data?["echo"] as? String == "ping")

    _ = paywallVc
  }

  @Test
  func noHandlerRegisteredWhenAdapterHasNone() async {
    let dependencyContainer = DependencyContainer()
    let paywall = Paywall.stub()
      .setting(\.identifier, to: "paywall_no_handler_test")

    let adapter = PaywallViewControllerDelegateAdapter(
      swiftDelegate: nil,
      objcDelegate: nil,
      onCustomCallback: nil
    )

    let paywallVc = makePaywallVc(paywall: paywall, delegate: adapter, in: dependencyContainer)

    let registered = dependencyContainer.customCallbackRegistry.getHandler(
      paywallIdentifier: paywall.identifier
    )
    #expect(registered == nil)

    _ = paywallVc
  }

  @Test
  func reassigningDelegateUpdatesRegistration() async {
    let dependencyContainer = DependencyContainer()
    let paywall = Paywall.stub()
      .setting(\.identifier, to: "paywall_reassign_test")

    let firstAdapter = PaywallViewControllerDelegateAdapter(
      swiftDelegate: nil,
      objcDelegate: nil,
      onCustomCallback: { _ in .success(data: ["origin": "first"]) }
    )

    let paywallVc = makePaywallVc(
      paywall: paywall,
      delegate: firstAdapter,
      in: dependencyContainer
    )

    let firstResult = await dependencyContainer.customCallbackRegistry.getHandler(
      paywallIdentifier: paywall.identifier
    )?(CustomCallback(name: "anything", variables: nil))
    #expect(firstResult?.data?["origin"] as? String == "first")

    let secondAdapter = PaywallViewControllerDelegateAdapter(
      swiftDelegate: nil,
      objcDelegate: nil,
      onCustomCallback: { _ in .success(data: ["origin": "second"]) }
    )
    paywallVc.delegate = secondAdapter

    let secondResult = await dependencyContainer.customCallbackRegistry.getHandler(
      paywallIdentifier: paywall.identifier
    )?(CustomCallback(name: "anything", variables: nil))
    #expect(secondResult?.data?["origin"] as? String == "second")

    paywallVc.delegate = nil

    let cleared = dependencyContainer.customCallbackRegistry.getHandler(
      paywallIdentifier: paywall.identifier
    )
    #expect(cleared == nil)
  }

  @Test
  func handlerIsUnregisteredWhenViewControllerDeinits() async {
    let dependencyContainer = DependencyContainer()
    let paywall = Paywall.stub()
      .setting(\.identifier, to: "paywall_deinit_test")

    weak var weakVc: PaywallViewControllerMock?
    autoreleasepool {
      let adapter = PaywallViewControllerDelegateAdapter(
        swiftDelegate: nil,
        objcDelegate: nil,
        onCustomCallback: { _ in .success(data: nil) }
      )
      let pvc = makePaywallVc(paywall: paywall, delegate: adapter, in: dependencyContainer)
      weakVc = pvc
      #expect(dependencyContainer.customCallbackRegistry.getHandler(
        paywallIdentifier: paywall.identifier
      ) != nil)
      _ = pvc
    }

    #expect(weakVc == nil)
    let registered = dependencyContainer.customCallbackRegistry.getHandler(
      paywallIdentifier: paywall.identifier
    )
    #expect(registered == nil)
  }
}
