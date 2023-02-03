//
//  SuperwallService.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//
// swiftlint:disable convenience_type

import SuperwallKit
import StoreKit

final class SuperwallService {
  static let shared = SuperwallService()
  #warning("For your own app you will need to use your own API key, available from the Superwall Dashboard")
  private static let apiKey = "pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9"
  static var name: String {
    return Superwall.shared.userAttributes["firstName"] as? String ?? ""
  }

  static func configure() {
    // Superwall handles subscription logic by default. However, if you'd
    // like more control you can handle it yourself via the SubscriptionController
    // in the delegate. If you're doing that, uncomment the following and other comments
    // further down:

    // Task {
    //   await StoreKitService.shared.loadSubscriptionState()
    // }

    Superwall.configure(
      apiKey: apiKey,
      delegate: shared
    )
  }

  static func identify() {
    do {
      try Superwall.shared.identify(userId: "abc")
    } catch let error as IdentityError {
      switch error {
      case .missingUserId:
        print("The provided userId was empty")
      }
    } catch {
      print("An unknown error occurred", error)
    }
  }

  static func reset() async {
    await Superwall.shared.reset()
  }

  static func handleDeepLink(_ url: URL) {
    Superwall.shared.handleDeepLink(url)
  }

  static func setName(to name: String) {
    Superwall.shared.setUserAttributes(["firstName": name])
  }
}

// MARK: - Superwall Delegate
extension SuperwallService: SuperwallDelegate {
  func didTrackSuperwallEventInfo(_ info: SuperwallEventInfo) {
    print("analytics event called", info.event.description)

    // Uncomment if you want to get a dictionary of params associated with the event:
    // print(info.params)

    // Uncomment the following if you want to track
    // Superwall events:
    /*
    switch info.event {
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
    case .deepLink(let url):
      <#code#>
    case .triggerFire(let eventName, let result):
      <#code#>
    case .paywallOpen(let paywallInfo):
      <#code#>
    case .paywallClose(let paywallInfo):
      <#code#>
    case .transactionStart(let product, let paywallInfo):
      <#code#>
    case .transactionFail(let error, let paywallInfo):
      <#code#>
    case .transactionAbandon(let product, let paywallInfo):
      <#code#>
    case .transactionComplete(let transaction, let product, let paywallInfo):
      <#code#>
    case .transactionTimeout(let paywallInfo):
      <#code#>
    case .subscriptionStart(let product, let paywallInfo):
      <#code#>
    case .freeTrialStart(let product, let paywallInfo):
      <#code#>
    case .transactionRestore(let paywallInfo):
      <#code#>
    case .userAttributes(let attributes):
      <#code#>
    case .nonRecurringProductPurchase(let product, let paywallInfo):
      <#code#>
    case .paywallResponseLoadStart(let triggeredEventName):
      <#code#>
    case .paywallResponseLoadNotFound(let triggeredEventName):
      <#code#>
    case .paywallResponseLoadFail(let triggeredEventName):
      <#code#>
    case .paywallResponseLoadComplete(let triggeredEventName, let paywallInfo):
      <#code#>
    case .paywallWebviewLoadStart(let paywallInfo):
      <#code#>
    case .paywallWebviewLoadFail(let paywallInfo):
      <#code#>
    case .paywallWebviewLoadComplete(let paywallInfo):
      <#code#>
    case .paywallWebviewLoadTimeout(let paywallInfo):
      <#code#>
    case .paywallProductsLoadStart(let triggeredEventName, let paywallInfo):
      <#code#>
    case .paywallProductsLoadFail(let triggeredEventName, let paywallInfo):
      <#code#>
    case .paywallProductsLoadComplete(let triggeredEventName):
      <#code#>
    case .paywallPresentationFail(reason: let reason):
      <#code#>
    }
    */
  }

  // Uncomment if you would like to handle subscription-related logic yourself:
  /*
  func subscriptionController() -> SubscriptionController? {
    return self
  }
}

// MARK: - SubscriptionController
extension SuperwallService: SubscriptionController {
  func purchase(product: SKProduct) async -> PurchaseResult {
    return await StoreKitService.shared.purchase(product)
  }

  func restorePurchases() async -> Bool {
    return await StoreKitService.shared.restorePurchases()
  }

  func isUserSubscribed() -> Bool {
    return StoreKitService.shared.isSubscribed
  }
  */
}
