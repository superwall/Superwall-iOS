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
  #warning("For your own app you will need to use your own API key, available from the Superwall Dashboard")
  static let apiKey = "pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9"
  static let shared = PaywallService()
  static var name: String {
    return Paywall.userAttributes["firstName"] as? String ?? ""
  }
  static func initPaywall() {
    Paywall.configure(
      apiKey: apiKey,
      delegate: shared
    )
  }

  static func handleDeepLink(_ url: URL) {
    Paywall.handleDeepLink(url)
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

  func trackAnalyticsEvent(
    withName name: String,
    params: [String: Any]
  ) {
    guard let event = SuperwallEvent(rawValue: name) else {
      return
    }
    // print("analytics event called", event, params)

    // Uncomment the following if you want to track the different analytics
    // events received from the paywall:

    /*
    switch event {
    case .firstSeen:
      <#code#>
    case .appOpen:
      <#code#>
    case .appLaunch:
      <#code#>
    case .appInstall:
      <#code#>
    case .sessionStart:
      <#code#>
    case .appClose:
      <#code#>
    case .deepLink:
      <#code#>
    case .triggerFire:
      <#code#>
    case .paywallOpen:
      <#code#>
    case .paywallClose:
      <#code#>
    case .transactionStart:
      <#code#>
    case .transactionFail:
      <#code#>
    case .transactionAbandon:
      <#code#>
    case .transactionComplete:
      <#code#>
    case .subscriptionStart:
      <#code#>
    case .freeTrialStart:
      <#code#>
    case .transactionRestore:
      <#code#>
    case .manualPresent:
      <#code#>
    case .userAttributes:
      <#code#>
    case .nonRecurringProductPurchase:
      <#code#>
    case .paywallResponseLoadStart:
      <#code#>
    case .paywallResponseLoadNotFound:
      <#code#>
    case .paywallResponseLoadFail:
      <#code#>
    case .paywallResponseLoadComplete:
      <#code#>
    case .paywallWebviewLoadStart:
      <#code#>
    case .paywallWebviewLoadFail:
      <#code#>
    case .paywallWebviewLoadComplete:
      <#code#>
    case .paywallWebviewLoadTimeout:
      <#code#>
    case .paywallProductsLoadStart:
      <#code#>
    case .paywallProductsLoadFail:
      <#code#>
    case .paywallProductsLoadComplete:
      <#code#>
    }
    */
  }
}
