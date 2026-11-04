//
//  NativeApplePayTests.swift
//  SuperwallKit
//
//  Created by Jake Mor on 04/11/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Foundation
import PassKit
import Testing

@Suite
struct NativeApplePayTests {
  /// Counts reads and records the thread each ran on.
  final class ReadLog: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    private var _ranOnMainThread = false

    var count: Int { lock.withLock { _count } }
    var ranOnMainThread: Bool { lock.withLock { _ranOnMainThread } }

    func record() {
      lock.withLock {
        _count += 1
        _ranOnMainThread = _ranOnMainThread || Thread.isMainThread
      }
    }
  }

  @Test
  func asksPassKitAboutAmexMastercardVisaAndDiscover() {
    #expect(NativeApplePay.cardNetworks == [
      PKPaymentNetwork.amex.rawValue,
      PKPaymentNetwork.masterCard.rawValue,
      PKPaymentNetwork.visa.rawValue,
      PKPaymentNetwork.discover.rawValue
    ])
  }

  @Test
  func asksForCreditAndDebitSeparately() {
    #expect(NativeApplePay.creditCapability == PKMerchantCapability.credit.rawValue)
    #expect(NativeApplePay.debitCapability == PKMerchantCapability.debit.rawValue)
  }

  /// The runtime calls must answer exactly what linking PassKit would. The
  /// answers depend on the Wallet of the machine running this, so they're
  /// compared rather than asserted.
  @Test
  func answersWhatPassKitAnswers() {
    let networks = NativeApplePay.cardNetworks.map { PKPaymentNetwork($0) }
    let expected = NativeApplePayCapabilities(
      isApplePayAvailable: PKPaymentAuthorizationController.canMakePayments(),
      hasCreditCard: PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks, capabilities: .credit),
      hasDebitCard: PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks, capabilities: .debit)
    )
    #expect(NativeApplePay.read() == expected)
  }

  @Test @MainActor
  func readsOnceOffTheMainThread() async {
    let log = ReadLog()
    let answer = NativeApplePayCapabilities(isApplePayAvailable: true, hasCreditCard: false, hasDebitCard: true)
    let reader = NativeApplePayReader {
      log.record()
      return answer
    }

    for _ in 0..<5 {
      #expect(await reader.capabilities == answer)
    }
    #expect(log.count == 1)
    #expect(!log.ranOnMainThread)
  }

  @Test
  func keepsTheOldAnswerWhenPassKitCannotLoad() {
    #expect(NativeApplePayCapabilities.passKitUnavailable.isApplePayAvailable)
    #expect(!NativeApplePayCapabilities.passKitUnavailable.hasCreditCard)
    #expect(!NativeApplePayCapabilities.passKitUnavailable.hasDebitCard)
  }
}
