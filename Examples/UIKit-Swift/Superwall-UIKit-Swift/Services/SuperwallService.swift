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

  static func configure() {
    // Superwall handles subscription logic by default. However, if you'd
    // like more control you can handle it yourself by providing a PurchaseController.
    // If you're doing that, uncomment the following and other comments
    // further down:

    // Task {
    //   await StoreKitService.shared.loadSubscriptionState()
    // }

    Superwall.configure(
      apiKey: apiKey/*,
      purchaseController: shared*/
    )
    Superwall.shared.delegate = shared
  }

  static func identify() {
    Superwall.shared.identify(userId: "abc")
  }

  static func reset() {
    Superwall.shared.reset()
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

  func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {

    print("track this analytics event in your own system", eventInfo.event.description)

    // Uncomment if you want to get a dictionary of params associated with the event:
    // print(info.params)

    // Uncomment the following if you want to track
    // Superwall events:
    /*
    switch eventInfo.event {
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
    case .subscriptionStatusDidChange:
      <#code#>
    }
    */
  }
}

// Uncomment to implement the PurchaseController:
/*
// MARK: - PurchaseController
extension SuperwallService: PurchaseController {
  func purchase(product: SKProduct) async -> PurchaseResult {
    return await StoreKitService.shared.purchase(product)
  }

  func restorePurchases() async -> Bool {
    return await StoreKitService.shared.restorePurchases()
  }
}
*/
