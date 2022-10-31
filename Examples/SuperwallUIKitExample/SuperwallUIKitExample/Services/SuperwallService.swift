//
//  SuperwallService.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import Superwall
import StoreKit

final class SuperwallService {
  static let shared = SuperwallService()
  #warning("For your own app you will need to use your own API key, available from the Superwall Dashboard")
  private let apiKey = "pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9"
  static var name: String {
    return Superwall.userAttributes["firstName"] as? String ?? ""
  }

  @MainActor
  func initSuperwall() -> Bool {
    Superwall.configure(
      apiKey: apiKey,
      delegate: self
    )

    // Checking our logged in status.
    return Superwall.isLoggedIn
  }

  static func logIn() async {
    do {
      try await Superwall.logIn(userId: "abc")
    } catch let error as LogInError {
      switch error {
      case .alreadyLoggedIn:
        print("The user is already logged in")
      case .missingUserId:
        print("The provided userId was empty")
      }
    } catch {
      print("An unknown error occurred", error)
    }
  }

  static func logOut() async {
    do {
      try await Superwall.logOut()
    } catch let error as LogoutError {
      switch error {
      case .notLoggedIn:
        print("The user is not logged in")
      }
    } catch {
      print("An unknown error occurred", error)
    }
  }

  static func handleDeepLink(_ url: URL) {
    Superwall.handleDeepLink(url)
  }

  static func setName(to name: String) {
    Superwall.setUserAttributes(["firstName": name])
  }
}

// MARK: - Superwall Delegate
extension SuperwallService: SuperwallDelegate {
  func purchase(product: SKProduct) async -> PurchaseResult {
    return await withCheckedContinuation { continuation in
      StoreKitService.shared.purchase(product) { result in
        continuation.resume(with: .success(result))
      }
    }
  }

  func restorePurchases() async -> Bool {
    return StoreKitService.shared.restorePurchases()
  }

  func isUserSubscribed() -> Bool {
    return StoreKitService.shared.isSubscribed.value
  }

  func trackAnalyticsEvent(
    withName name: String,
    params: [String: Any]
  ) {
    guard let event = SuperwallEvent(rawValue: name) else {
      return
    }
    print("analytics event called", event, params)

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
