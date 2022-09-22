//
//  PaywallCache.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

@MainActor
final class PaywallCache {
  func getPaywall(
    withIdentifier identifier: String?
  ) -> SWPaywallViewController? {
    let key = PaywallCacheLogic.key(
      forIdentifier: identifier
    )
    return SWPaywallViewController.cache.first { $0.cacheKey == key }
  }

  func getPaywall(withKey key: String) -> SWPaywallViewController? {
    return SWPaywallViewController.cache.first { $0.cacheKey == key }
  }

  func removePaywall(
    withIdentifier identifier: String?
  ) {
    if let viewController = getPaywall(withIdentifier: identifier) {
      SWPaywallViewController.cache.remove(viewController)
    }
  }

  func removePaywall(withViewController viewController: SWPaywallViewController) {
    SWPaywallViewController.cache.remove(viewController)
  }

  func clearCache() {
    // don't remove the reference to a presented paywall
    for viewController in SWPaywallViewController.cache where !viewController.isActive {
      SWPaywallViewController.cache.remove(viewController)
    }
  }
}
