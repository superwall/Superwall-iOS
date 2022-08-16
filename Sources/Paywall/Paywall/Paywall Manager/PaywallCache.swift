//
//  PaywallCache.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

final class PaywallCache {

  func getPaywall(
    withIdentifier identifier: String?
  ) -> SWPaywallViewController? {
    let key = PaywallCacheLogic.key(
      forIdentifier: identifier
    )

    let total = SWPaywallViewController.cache.filter { $0.cacheKey == key }

    
    if total.count > 1 {
      print("match count", total.count)
    }

    return SWPaywallViewController.cache.first { $0.cacheKey == key }
  }

  func getPaywall(withKey key: String) -> SWPaywallViewController? {
    return SWPaywallViewController.cache.first { $0.cacheKey == key }
  }


  func removePaywall(
    withIdentifier identifier: String?
  ) {
    if let vc = getPaywall(withIdentifier: identifier) {
      SWPaywallViewController.cache.remove(vc)
    }
  }

  func removePaywall(withViewController viewController: SWPaywallViewController) {
    SWPaywallViewController.cache.remove(viewController)
  }

  func clearCache() {
    for vc in SWPaywallViewController.cache {
      // don't remove the reference to a presented paywall
      if !vc.isActive {
        SWPaywallViewController.cache.remove(vc)
      } 
    }
  }
}
