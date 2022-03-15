//
//  PaywallService.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import Paywall
import StoreKit

// swiftlint:disable:next convenience_type
final class PaywallService {
  #warning("Replace the following with your own API key, available from the Superwall Dashboard:")
  static let apiKey = "pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9"
  static var shared = PaywallService()
  static var name: String {
    return Paywall.userAttributes["firstName"] as? String ?? ""
  }
  static func initPaywall() {
    Paywall.configure(
      apiKey: apiKey,
      delegate: shared
    )
  }

  static func trackDeepLink(url: URL) {
    Paywall.track(.deepLinkOpen(deepLinkUrl: url))
  }

  static func setName(to name: String) {
    Paywall.setUserAttributes(["firstName": name])
  }
}

// MARK: - Paywall Delegate
extension PaywallService: PaywallDelegate {
  func purchase(product: SKProduct) {
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
