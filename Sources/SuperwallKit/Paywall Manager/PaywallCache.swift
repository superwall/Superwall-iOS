//
//  PaywallCache.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

final class PaywallCache: Sendable {
  private let deviceLocaleString: String

  init(deviceLocaleString: String) {
    self.deviceLocaleString = deviceLocaleString
  }

  @MainActor
  func getPaywallViewController(
    withIdentifier identifier: String?
  ) -> PaywallViewController? {
    let key = PaywallCacheLogic.key(
      forIdentifier: identifier,
      locale: deviceLocaleString
    )
    return PaywallViewController.cache.first { $0.cacheKey == key }
  }

  @MainActor
  func getPaywall(withKey key: String) -> PaywallViewController? {
    return PaywallViewController.cache.first { $0.cacheKey == key }
  }

  @MainActor
  func removePaywall(
    withIdentifier identifier: String?
  ) {
    if let viewController = getPaywallViewController(withIdentifier: identifier) {
      PaywallViewController.cache.remove(viewController)
    }
  }

  @MainActor
  func removePaywall(withViewController viewController: PaywallViewController) {
    PaywallViewController.cache.remove(viewController)
  }

  @MainActor
  func clearCache() {
    // don't remove the reference to a presented paywall
    for viewController in PaywallViewController.cache where !viewController.isActive {
      PaywallViewController.cache.remove(viewController)
    }
  }
}
