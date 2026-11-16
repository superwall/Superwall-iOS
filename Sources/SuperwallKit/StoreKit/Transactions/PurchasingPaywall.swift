//
//  PurchasingPaywall.swift
//  SuperwallKit
//
//  Created by Superwall on 16/11/2026.
//

#if canImport(WebKit)
import Foundation

/// What the purchase and restore flows ask of the paywall a purchase or
/// restore came from. ``PaywallViewController`` is the real one, and tests
/// use a fake that records the calls.
@MainActor
protocol PurchasingPaywall: AnyObject {
  var info: PaywallInfo { get }

  /// The paywall's intro offer token for the product, if it has one that
  /// hasn't expired.
  func introOfferToken(forProductId productId: String) -> IntroOfferToken?

  /// The name the paywall gives the product in the slot with this
  /// `Product.cacheKey`.
  func referenceName(forCacheKey cacheKey: String) -> String?

  /// Tells the paywall's page what happened.
  func notify(of message: PaywallMessage)

  func updateLoading(_ change: PaywallLoadingChange)

  /// Records a completed purchase before the page hears of it.
  func markPurchaseCompleted(_ product: StoreProduct)

  /// The custom store checkout the paywall ran has ended, and its page
  /// already knows.
  func customStoreCheckoutFinished()

  /// Shows an alert over the paywall. `action` runs when the button titled
  /// `actionTitle` is chosen.
  func showAlert(
    title: String,
    message: String,
    actionTitle: String?,
    closeActionTitle: String,
    action: (() -> Void)?
  )
}

extension PaywallViewController: PurchasingPaywall {
  func introOfferToken(forProductId productId: String) -> IntroOfferToken? {
    return introOfferTokenManager.getValidToken(for: productId)
  }

  func referenceName(forCacheKey cacheKey: String) -> String? {
    return paywall.referenceName(forCacheKey: cacheKey)
  }

  func notify(of message: PaywallMessage) {
    webView.messageHandler.handle(message)
  }

  func showAlert(
    title: String,
    message: String,
    actionTitle: String?,
    closeActionTitle: String,
    action: (() -> Void)?
  ) {
    presentAlert(
      title: title,
      message: message,
      actionTitle: actionTitle,
      closeActionTitle: closeActionTitle,
      action: action
    )
  }
}
#endif
