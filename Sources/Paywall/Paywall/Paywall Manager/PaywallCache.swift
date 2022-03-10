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
    forIdentifier identifier: String?,
    event: EventData?
  ) -> SWPaywallViewController? {
    let key = PaywallCacheLogic.key(
      forIdentifier: identifier,
      event: event
    )
    return cache[key]
  }

  func getPaywall(withKey key: String) -> SWPaywallViewController? {
    return cache[key]
  }

  func savePaywall(
    _ viewController: SWPaywallViewController,
    withIdentifier identifier: String?,
    forEvent event: EventData?
  ) {
    let key = PaywallCacheLogic.key(
      forIdentifier: identifier,
      event: event
    )

    self.cache[key] = viewController
  }

  func removePaywall(
    withIdentifier identifier: String?,
    forEvent event: EventData?
  ) {
    let key = PaywallCacheLogic.key(
      forIdentifier: identifier,
      event: event
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
