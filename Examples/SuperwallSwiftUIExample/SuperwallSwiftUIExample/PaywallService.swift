//
//  PaywallService.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import Foundation
import Paywall
import StoreKit

// swiftlint:disable:next convenience_type
final class PaywallService {
  static var shared = PaywallService()

  static func initPaywall() {
    Paywall.configure(
      apiKey: "pk_9275c350783c8062dbd6a905b66915c00319c27d714a9272"
    )
    Paywall.delegate = shared
  }
}

// MARK: - Paywall Delegate
extension PaywallService: PaywallDelegate {
  func purchase(product: SKProduct) {}

  func restorePurchases(completion: @escaping (Bool) -> Void) {
    completion(true)
  }

  func isUserSubscribed() -> Bool {
    return false
  }
}
