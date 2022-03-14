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
  #warning("Replace this with your own API key, available from the Superwall Dashboard:")
  static let apiKey = "pk_9275c350783c8062dbd6a905b66915c00319c27d714a9272"

  static var shared = PaywallService()

  static func initPaywall() {
    Paywall.configure(
      apiKey: apiKey
    )
    Paywall.delegate = shared
  }

  static func trackDeepLink(url: URL) {
    Paywall.track(.deepLinkOpen(deepLinkUrl: url))
  }
}

// MARK: - Paywall Delegate
extension PaywallService: PaywallDelegate {
  func purchase(product: SKProduct) {
    print("purchase!")
    Task {
      try? await StoreKitService.shared.purchase(product)
    }
  }

  func restorePurchases(completion: @escaping (Bool) -> Void) {
    let result = StoreKitService.shared.restorePurchases()
    completion(result)
  }

  func isUserSubscribed() -> Bool {
    return StoreKitService.shared.isSubscribed
  }
}
