//
//  PaywallCache.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

final class PaywallCache {
  var viewControllers: Dictionary<String, SWPaywallViewController>.Values {
    return cache.values
  }
  private var cache: [String: SWPaywallViewController] = [:]

  func getPaywall(
    withIdentifier identifier: String?
  ) -> SWPaywallViewController? {
    let key = PaywallCacheLogic.key(
      forIdentifier: identifier
    )
    return cache[key]
  }

  func getPaywall(withKey key: String) -> SWPaywallViewController? {
    return cache[key]
  }

  func savePaywall(
    _ viewController: SWPaywallViewController,
    withIdentifier identifier: String?
  ) {
    let key = PaywallCacheLogic.key(
      forIdentifier: identifier
    )
    self.cache[key] = viewController
  }

  func removePaywall(
    withIdentifier identifier: String?
  ) {
    let key = PaywallCacheLogic.key(
      forIdentifier: identifier
    )
    cache[key] = nil
  }

  func removePaywall(withViewController viewController: SWPaywallViewController) {
    let keys = cache.allKeys(forValue: viewController)
    keys.forEach { cache[$0] = nil }
  }

  func clearCache() {
    cache.removeAll()
  }
}
