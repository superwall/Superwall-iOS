//
//  Config.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct Config: Decodable {
  var triggers: Set<Trigger>
  var paywalls: Set<PaywallConfig> // not used anymore
  var logLevel: Int
  var postback: PostbackRequest
  var localization: LocalizationConfig
  var appSessionTimeout: Milliseconds

  enum CodingKeys: String, CodingKey {
    case triggers
    case paywalls
    case logLevel
    case postback
    case localization
    case appSessionTimeout = "appSessionTimeoutMs"
  }

  /// Preloads paywalls, products, trigger paywalls, and trigger responses. It then sends the products back to the server.
  ///
  /// A developer can disable preloading of paywalls by setting ``Paywall/Paywall/shouldPreloadPaywalls``
  func cache() {
    if Paywall.options.shouldPreloadPaywalls {
      preloadAllPaywalls()
    } else {
      preloadAllPaywallResponses()
    }
    executePostback()
  }

  /// Preloads only the paywall responses
  internal func preloadAllPaywallResponses() {
    let triggerPaywallIdentifiers = ConfigResponseLogic.getPaywallIds(fromTriggers: triggers)
    for identifier in triggerPaywallIdentifiers {
      PaywallResponseManager.shared.getResponse(
        withIdentifiers: .init(paywallId: identifier)) { _ in

        }
    }
  }

  /// Preloads paywalls referenced by triggers.
  internal func preloadAllPaywalls() {
    let triggerPaywallIdentifiers = ConfigResponseLogic.getPaywallIds(fromTriggers: triggers)
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  /// Preloads paywalls referenced by the provided triggers.
  internal func preloadPaywalls(forTriggers triggerEvents: [String]) {
    let triggerSet = Set(triggerEvents)
    let triggersToPreload = self.triggers.filter { triggerSet.contains($0.eventName) }
    let triggerPaywallIdentifiers = ConfigResponseLogic.getPaywallIds(fromTriggers: triggersToPreload)
    preloadPaywalls(withIdentifiers: triggerPaywallIdentifiers)
  }

  /// Preloads paywalls referenced by triggers.
  private func preloadPaywalls(withIdentifiers paywallIdentifiers: Set<String>) {
    for identifier in paywallIdentifiers {
      PaywallManager.shared.getPaywallViewController(
        responseIdentifiers: .init(paywallId: identifier),
        cached: true
      )
    }
  }

  /// This sends product data back to the dashboard
  private func executePostback() {
    // TODO: Does this need to be on the main thread?
    DispatchQueue.main.asyncAfter(deadline: .now() + postback.postbackDelay) {
      let productIds = postback.productsToPostBack.map { $0.identifier }
      StoreKitManager.shared.getProducts(withIds: productIds) { result in
        switch result {
        case .success(let productsById):
          let products = productsById.values.map(PostbackProduct.init)
          let postback = Postback(products: products)
          Network.shared.sendPostback(postback)
        case .failure:
          break
        }
      }
    }
  }
}

// MARK: - Stubbable
extension Config: Stubbable {
  static func stub() -> Config {
    return Config(
      triggers: [.stub()],
      paywalls: [.stub()],
      logLevel: 0,
      postback: .stub(),
      localization: .stub(),
      appSessionTimeout: 3600000
    )
  }
}
