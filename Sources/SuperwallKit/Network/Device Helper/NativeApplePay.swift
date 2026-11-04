//
//  NativeApplePay.swift
//  SuperwallKit
//
//  Created by Jake Mor on 04/11/2026.
//

import Foundation
import ObjectiveC

/// What PassKit says about Apple Pay on this device, reported as the
/// `isApplePayAvailable`, `hasApplePayCreditCard` and `hasApplePayDebitCard`
/// device attributes.
///
/// These are native answers and can under-report: some users whose card flags
/// read `false` have gone on to pay with Apple Pay. For web checkout,
/// `webApplePayReadiness` is the signal to route on, since it asks the browser
/// about the checkout's own merchant. PassKit has no prepaid capability, so a
/// prepaid card most likely reads as debit.
struct NativeApplePayCapabilities: Equatable {
  /// The device supports Apple Pay, whether or not a card is in Wallet.
  let isApplePayAvailable: Bool
  /// Wallet has an Amex, Mastercard, Visa or Discover card that can pay as credit.
  let hasCreditCard: Bool
  /// Wallet has an Amex, Mastercard, Visa or Discover card that can pay as debit.
  let hasDebitCard: Bool

  /// Reported when PassKit can't be loaded. `isApplePayAvailable` keeps the
  /// value it had before it was measured.
  static let passKitUnavailable = NativeApplePayCapabilities(
    isApplePayAvailable: true,
    hasCreditCard: false,
    hasDebitCard: false
  )
}

/// Reads ``NativeApplePayCapabilities`` once per launch, off the main thread.
///
/// The first read can take a few hundred milliseconds while PassKit reaches its
/// daemon, so it starts when the SDK is configured and every later read gets
/// the cached answer.
final class NativeApplePayReader: @unchecked Sendable {
  private let read: Task<NativeApplePayCapabilities, Never>

  init(read: @escaping @Sendable () -> NativeApplePayCapabilities = { NativeApplePay.read() }) {
    self.read = Task.detached(priority: .utility) {
      read()
    }
  }

  var capabilities: NativeApplePayCapabilities {
    get async {
      await read.value
    }
  }
}

/// Calls `PKPaymentAuthorizationController` without linking PassKit.
///
/// SuperwallKit stopped importing PassKit in 4.11.2 because the import was
/// getting flagged for some developers in App Review, so the framework is
/// loaded and called at runtime instead, and apps don't link it. It's the
/// `PKPaymentAuthorizationController` class methods, not the view controller's:
/// the view controller is UIKit and crashed when read off the main thread.
enum NativeApplePay {
  /// `PKPaymentNetwork` raw values for Amex, Mastercard, Visa and Discover.
  static let cardNetworks: [String] = ["AmEx", "MasterCard", "Visa", "Discover"]
  /// `PKMerchantCapability.credit` and `.debit`.
  static let creditCapability: UInt = 1 << 2
  static let debitCapability: UInt = 1 << 3

  private static let passKitPath = "/System/Library/Frameworks/PassKit.framework"

  static func read() -> NativeApplePayCapabilities {
    guard let controller = paymentAuthorizationController() else {
      return .passKitUnavailable
    }
    return NativeApplePayCapabilities(
      isApplePayAvailable: canMakePayments(controller),
      hasCreditCard: canMakePayments(controller, capabilities: creditCapability),
      hasDebitCard: canMakePayments(controller, capabilities: debitCapability)
    )
  }

  private static func paymentAuthorizationController() -> AnyClass? {
    if let controller = NSClassFromString("PKPaymentAuthorizationController") {
      return controller
    }
    guard Bundle(path: passKitPath)?.load() == true else {
      return nil
    }
    return NSClassFromString("PKPaymentAuthorizationController")
  }

  private static func canMakePayments(_ controller: AnyClass) -> Bool {
    typealias Function = @convention(c) (AnyClass, Selector) -> ObjCBool
    let selector = NSSelectorFromString("canMakePayments")
    guard let method = class_getClassMethod(controller, selector) else {
      return false
    }
    let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
    return function(controller, selector).boolValue
  }

  private static func canMakePayments(_ controller: AnyClass, capabilities: UInt) -> Bool {
    typealias Function = @convention(c) (AnyClass, Selector, NSArray, UInt) -> ObjCBool
    let selector = NSSelectorFromString("canMakePaymentsUsingNetworks:capabilities:")
    guard let method = class_getClassMethod(controller, selector) else {
      return false
    }
    let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
    return function(controller, selector, cardNetworks as NSArray, capabilities).boolValue
  }
}
