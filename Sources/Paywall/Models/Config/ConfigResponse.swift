//
//  ConfigResponse.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct ConfigResponse: Decodable {
  var triggers: Set<Trigger>
  var paywalls: Set<PaywallConfig>
  var logLevel: Int
  var postback: PostbackRequest
  var localization: LocalizationConfig

  func cache() {
    preloadPaywallsAndProducts()
    preloadTriggerPaywalls()
    preloadDefaultPaywall()
    preloadTriggerResponses()
    executePostback()
  }

  /// Preloads paywalls and their products.
  private func preloadPaywallsAndProducts() {
    for paywall in paywalls {
      // cache paywall's products
      let productIds = paywall.products.map { $0.identifier }
      StoreKitManager.shared.getProducts(withIds: productIds)

      // cache the view controller
      PaywallManager.shared.getPaywallViewController(
        withIdentifier: paywall.identifier,
        event: nil,
        cached: true
      )
    }
  }

  /// Pre-loads all the paywalls referenced by v2 triggers.
  private func preloadTriggerPaywalls() {
    let triggerPaywallIds = ConfigResponseLogic.getPaywallIds(fromTriggers: triggers)

    for id in triggerPaywallIds {
      PaywallManager.shared.getPaywallViewController(
        withIdentifier: id,
        event: nil,
        cached: true
      )
    }
  }

  /// Preloads the default paywall for the user. This is the paywall shown when calling paywall.present().
  private func preloadDefaultPaywall() {
    PaywallManager.shared.getPaywallViewController(
      withIdentifier: nil,
      event: nil,
      cached: true
    )
  }

  /// This preloads and caches the responses and associated products for each trigger.
  private func preloadTriggerResponses() {
    guard Paywall.shouldPreloadTriggers else {
      return
    }

    let triggerNames = ConfigResponseLogic.getNames(of: triggers)

    for triggerName in triggerNames {
      let eventData = EventData(
        name: triggerName,
        parameters: JSON(["caching": true]),
        createdAt: Date().isoString
      )
      // Preload the response for that trigger
      PaywallResponseManager.shared.getResponse(
        event: eventData
      ) { _ in }
    }
  }

  /// This sends product data back to the dashboard
  private func executePostback() {
    // TODO: Does this need to be on the main thread?
    DispatchQueue.main.asyncAfter(deadline: .now() + postback.postbackDelay) {
      let productIds = postback.productsToPostBack.map { $0.identifier }
      StoreKitManager.shared.getProducts(withIds: productIds) { productsById in
        let products = productsById.values.map(PostbackProduct.init)
        let postback = Postback(products: products)
        Network.shared.sendPostback(postback)
      }
    }
  }
}
