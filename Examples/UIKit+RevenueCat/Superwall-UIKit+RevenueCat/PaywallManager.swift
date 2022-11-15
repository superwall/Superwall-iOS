//
//  PaywallManager.swift
//  Superwall-UIKit+RevenueCat
//
//  Created by Yusuf Tör on 14/11/2022.
//

import SuperwallKit
import StoreKit
import RevenueCat

final class PaywallManager: NSObject {
  static let shared = PaywallManager()
  static var name: String {
    return Superwall.userAttributes["firstName"] as? String ?? ""
  }
  @Published var isSubscribed = false {
    didSet {
      UserDefaults.standard.set(isSubscribed, forKey: kIsSubscribed)
    }
  }
  private let kIsSubscribed = "isSubscribed"

  #warning("Replace these with your API keys:")
  private static let revenueCatApiKey = "appl_XmYQBWbTAFiwLeWrBJOeeJJtTql"
  private static let superwallApiKey = "pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9"

  #warning("Replace with your own pro revenuecat entitlement:")
  private let proEntitlement = "pro"

  override init() {
    isSubscribed = UserDefaults.standard.bool(forKey: kIsSubscribed)
    super.init()
  }

  /// Configures both the RevenueCat and Superwall SDKs.
  ///
  /// Call this on `application(_:didFinishLaunchingWithOptions:)`
  static func configure() {
    Purchases.configure(withAPIKey: revenueCatApiKey)
    Purchases.shared.delegate = shared

    Superwall.configure(
      apiKey: superwallApiKey,
      delegate: shared
    )
  }

  /// Logs the user in to both RevenueCat and Superwall with the specified `userId`.
  ///
  /// Call this when you retrieve a userId.
  static func logIn(userId: String) async {
    do {
      let (customerInfo, _) = try await Purchases.shared.logIn(userId)
      shared.updateSubscriptionStatus(using: customerInfo)

      try await Superwall.logIn(userId: userId)
    } catch let error as IdentityError {
      switch error {
      case .alreadyLoggedIn:
        print("The user is already logged in to Superwall")
      case .missingUserId:
        print("The provided userId was empty")
      }
    } catch {
      print("A RevenueCat error occurred", error)
    }
  }

  /// Logs the user out of RevenueCat and Superwall.
  ///
  /// Call this when your user logs out.
  func logOut() async {
    do {
      let customerInfo = try await Purchases.shared.logOut()
      updateSubscriptionStatus(using: customerInfo)
      try await Superwall.logOut()
    } catch let error as LogoutError {
      switch error {
      case .notLoggedIn:
        print("The user was not logged in to Superwall")
      }
    } catch {
      print("A RevenueCat error occurred", error)
    }
  }

  /// Handles a deep link to open a paywall preview.
  ///
  /// [See here](https://docs.superwall.com/v3.0/docs/in-app-paywall-previews#handling-deep-links)
  /// for information on how to call this function in your app.
  static func handleDeepLink(_ url: URL) {
    Superwall.handleDeepLink(url)
  }

  /// Settting Superwall attributes.
  static func setName(to name: String) {
    Superwall.setUserAttributes(["firstName": name])
  }
}

// MARK: - Purchases Delegate
extension PaywallManager: PurchasesDelegate {
  /// Handles updated CustomerInfo received from RevenueCat.
  func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    updateSubscriptionStatus(using: customerInfo)
  }

  /// Updates the subscription status in response to customer info received from RevenueCat.
  private func updateSubscriptionStatus(using customerInfo: CustomerInfo) {
    isSubscribed = customerInfo.entitlements.active[proEntitlement] != nil
  }

  /// Restores purchases and updates subscription status.
  ///
  /// - Returns: A boolean indicating whether the user restored a purchase or not.
  private func restore() async -> Bool {
    do {
      let customerInfo = try await Purchases.shared.restorePurchases()
      updateSubscriptionStatus(using: customerInfo)
      return customerInfo.entitlements.active[proEntitlement] != nil
    } catch {
      return false
    }
  }

  /// Purchases a product with RevenueCat.
  ///
  /// - Returns: A boolean indicating whether the user cancelled or not.
  private func purchase(_ product: SKProduct) async throws -> Bool {
    let storeProduct = StoreProduct(sk1Product: product)
    let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(product: storeProduct)
    updateSubscriptionStatus(using: customerInfo)
    return userCancelled
  }
}

// MARK: - Superwall Delegate
extension PaywallManager: SuperwallDelegate {
  /// Purchase a product from a paywall.
  func purchase(product: SKProduct) async -> PurchaseResult {
    do {
      let userCancelled = try await purchase(product)
      return userCancelled ? .cancelled : .purchased
    } catch let error as ErrorCode {
      switch error {
      case .paymentPendingError:
        return .pending
      default:
        return .failed(error)
      }
    } catch {
      return .failed(error)
    }
  }

  /// Restore purchases
  func restorePurchases() async -> Bool {
    return await restore()
  }

  /// Lets Superwall know whether the user is subscribed or not.
  func isUserSubscribed() -> Bool {
    return isSubscribed
  }

  func didTrackSuperwallEvent(_ info: SuperwallEventInfo) {
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
