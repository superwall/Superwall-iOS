//
//  SuperwallService.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SuperwallKit
import StoreKit
import Combine

// swiftlint:disable:next convenience_type
final class SuperwallService {
  #warning("For your own app you will need to use your own API key, available from the Superwall Dashboard")
  static let apiKey = "pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9"
  static let shared = SuperwallService()
  static var name: String {
    return Superwall.userAttributes["firstName"] as? String ?? ""
  }
  var isLoggedIn = CurrentValueSubject<Bool, Never>(false)

  static func initSuperwall() {
    Superwall.configure(
      apiKey: apiKey,
      delegate: shared
    )

    // Getting our logged in status to Superwall.
    shared.isLoggedIn.send(Superwall.isLoggedIn)
  }

  static func logIn() async {
    do {
      try await Superwall.logIn(userId: "abc")
    } catch let error as LogInError {
      switch error {
      case .missingUserId:
        print("The provided userId was empty")
      case .alreadyLoggedIn:
        print("The user is already logged in")
      }
    } catch {
      print("Unexpected error", error)
    }
  }

  static func logOut() async {
    do {
      try await Superwall.logOut()
    } catch LogoutError.notLoggedIn {
      print("The user is not logged in")
    } catch {
      print("Unexpected error", error)
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

  func didTrackSuperwallEvent(_ result: SuperwallEventResult) {
    print("analytics event called", result.event.description)

    // Uncomment if you want to get a dictionary of params associated with the event:
    // print(result.params)

    // Uncomment the following if you want to track
    // Superwall events:

    /*
    switch result.event {
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
