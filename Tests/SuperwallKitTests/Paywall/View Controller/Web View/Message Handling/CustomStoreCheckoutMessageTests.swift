//
//  CustomStoreCheckoutMessageTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 2026-10-21.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Decoding and forwarding of the messages a paywall sends while it runs a
/// custom store checkout.
@Suite
@MainActor
struct CustomStoreCheckoutMessageTests {
  private func decode(_ event: String) throws -> PaywallMessage? {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [\(event)]
      }
    }
    """
    let data = json.data(using: .utf8)!
    let wrapped = try JSONDecoder.fromSnakeCase.decode(WrappedPaywallMessages.self, from: data)
    return wrapped.payload.messages.first
  }

  // MARK: - Decoding

  @Test("custom_checkout_start decodes the product and transaction id")
  func decodeStart() throws {
    let message = try decode("""
      {
        "event_name": "custom_checkout_start",
        "checkout_context_id": "ctx_123",
        "product_identifier": "pro_monthly",
        "custom_transaction_id": "txn_123"
      }
      """)

    #expect(message == .customCheckoutStart(productId: "pro_monthly", customTransactionId: "txn_123"))
  }

  @Test("custom_checkout_start without a transaction id doesn't decode")
  func decodeStart_withoutTransactionId_fails() {
    #expect(throws: (any Error).self) {
      try decode("""
        {
          "event_name": "custom_checkout_start",
          "checkout_context_id": "ctx_123",
          "product_identifier": "pro_monthly"
        }
        """)
    }
  }

  @Test("custom_checkout_complete decodes should_dismiss", arguments: [true, false])
  func decodeComplete(shouldDismiss: Bool) throws {
    let message = try decode("""
      {
        "event_name": "custom_checkout_complete",
        "product_identifier": "pro_monthly",
        "custom_transaction_id": "txn_123",
        "should_dismiss": \(shouldDismiss)
      }
      """)

    #expect(message == .customCheckoutComplete(
      productId: "pro_monthly",
      customTransactionId: "txn_123",
      shouldDismiss: shouldDismiss
    ))
  }

  @Test("custom_checkout_complete dismisses by default, like purchase")
  func decodeComplete_withoutShouldDismiss_dismisses() throws {
    let message = try decode("""
      {
        "event_name": "custom_checkout_complete",
        "product_identifier": "pro_monthly",
        "custom_transaction_id": "txn_123"
      }
      """)

    #expect(message == .customCheckoutComplete(
      productId: "pro_monthly",
      customTransactionId: "txn_123",
      shouldDismiss: true
    ))
  }

  @Test("custom_checkout_abandon without a reason is the buyer's")
  func decodeAbandon() throws {
    let message = try decode("""
      {
        "event_name": "custom_checkout_abandon",
        "product_identifier": "pro_monthly"
      }
      """)

    #expect(message == .customCheckoutAbandon(productId: "pro_monthly", reason: .buyer))
  }

  @Test("custom_checkout_abandon decodes its reason, and an unknown one is the buyer's", arguments: [
    ("buyer", CustomStoreCheckout.AbandonReason.buyer),
    ("paywall_closed", .paywallClosed),
    ("timeout", .timeout),
    ("something_new", .buyer)
  ])
  func decodeAbandonReason(reason: String, expected: CustomStoreCheckout.AbandonReason) throws {
    let message = try decode("""
      {
        "event_name": "custom_checkout_abandon",
        "product_identifier": "pro_monthly",
        "reason": "\(reason)"
      }
      """)

    #expect(message == .customCheckoutAbandon(productId: "pro_monthly", reason: expected))
  }

  @Test("custom_checkout_fail decodes the product and message")
  func decodeFail() throws {
    let message = try decode("""
      {
        "event_name": "custom_checkout_fail",
        "product_identifier": "pro_monthly",
        "message": "Checkout is unavailable"
      }
      """)

    #expect(message == .customCheckoutFail(productId: "pro_monthly", message: "Checkout is unavailable"))
  }

  @Test("custom_checkout_fail without a message decodes with an empty one")
  func decodeFail_withoutMessage() throws {
    let message = try decode("""
      {
        "event_name": "custom_checkout_fail",
        "product_identifier": "pro_monthly"
      }
      """)

    #expect(message == .customCheckoutFail(productId: "pro_monthly", message: ""))
  }

  // MARK: - Forwarding

  @Test("Each message is forwarded to the delegate as a checkout step")
  func handle_forwardsEachStepToDelegate() {
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

    messageHandler.handle(.customCheckoutStart(productId: "pro_monthly", customTransactionId: "txn_123"))
    messageHandler.handle(.customCheckoutComplete(
      productId: "pro_monthly",
      customTransactionId: "txn_123",
      shouldDismiss: false
    ))
    messageHandler.handle(.customCheckoutAbandon(productId: "pro_monthly", reason: .timeout))
    messageHandler.handle(.customCheckoutFail(productId: "pro_monthly", message: "Unavailable"))

    #expect(delegate.customStoreCheckouts == [
      .start(productId: "pro_monthly", customTransactionId: "txn_123"),
      .complete(productId: "pro_monthly", customTransactionId: "txn_123", shouldDismiss: false),
      .abandon(productId: "pro_monthly", reason: .timeout),
      .fail(productId: "pro_monthly", message: "Unavailable")
    ])
    // Nothing goes through the purchase path.
    #expect(delegate.eventDidOccur == nil)
  }

  // MARK: - Capability

  @Test("The SDK advertises the custom_store_checkout capability to the paywall")
  func templateDevice_advertisesCapability() async {
    let dependencyContainer = DependencyContainer()

    let template = await dependencyContainer.deviceHelper.getTemplateDevice()

    let capabilities = (template["capabilities"] as? String)?.split(separator: ",").map(String.init)
    #expect(capabilities?.contains("custom_store_checkout") == true)
  }
}
