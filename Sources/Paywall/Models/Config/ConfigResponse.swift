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

  func cache() {
    preloadPaywallsAndProducts()
    preloadTriggerPaywalls()
    preloadDefaultPaywall()
    preloadTriggerResponses()
    executePostback()
  }

  private func preloadPaywallsAndProducts() {
    for paywall in paywalls {
      // cache paywall's products
      let productIds = paywall.products.map { $0.identifier }
      StoreKitManager.shared.getProducts(withIds: productIds)

      // cache the view controller
      PaywallManager.shared.viewController(
        identifier: paywall.identifier,
        event: nil,
        cached: true,
        completion: nil
      )
    }
  }

  private func preloadTriggerPaywalls() {
    let triggerPaywallIds = ConfigResponseLogic.getPaywallIds(from: triggers)
    // Pre-load all the paywalls from v2 triggers
    for id in triggerPaywallIds {
      PaywallManager.shared.viewController(identifier: id, event: nil, cached: true, completion: nil)
    }
  }

  private func preloadDefaultPaywall() {
    // cache paywall.present(), when identifier and event is nil
    PaywallManager.shared.viewController(identifier: nil, event: nil, cached: true, completion: nil)
  }

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

  private func executePostback() {
    // TODO: Does this need to be on the main thread?
    DispatchQueue.main.asyncAfter(deadline: .now() + postback.postbackDelay) {
      StoreKitManager.shared.getProducts(withIds: postback.productsToPostBack.map { $0.identifier }) { productsById in
        let products = productsById.values.map(PostbackProduct.init)
        let postback = Postback(products: products)
        Network.shared.postback(postback) { _ in }
      }
    }
  }
}
