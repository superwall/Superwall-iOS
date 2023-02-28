//
//  PaywallCache.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

final class PaywallViewControllerCache {
  var activePaywallVcKey: String?
  private let queue = DispatchQueue(label: "com.superwall.paywallcache")
  private var cache: [String: PaywallViewController] = [:]
  private let deviceLocaleString: String

  init(deviceLocaleString: String) {
    self.deviceLocaleString = deviceLocaleString
  }

  func save(_ paywallViewController: PaywallViewController, forKey key: String) {
    queue.async { [weak self] in
      self?.cache[key] = paywallViewController
    }
  }

  func getPaywallViewController(forKey key: String) -> PaywallViewController? {
    var result: PaywallViewController?
    queue.sync { [weak self] in
      result = self?.cache[key]
    }
    return result
  }

  func getActivePaywallViewController() -> PaywallViewController? {
    guard let activePaywallVcKey = activePaywallVcKey else {
      return nil
    }

    return getPaywallViewController(forKey: activePaywallVcKey)
  }

  func removePaywallViewController(forKey key: String) {
    queue.async { [weak self] in
      self?.cache.removeValue(forKey: key)
    }
  }

  func removeAll() {
    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      for key in self.cache.keys {
        if key == self.activePaywallVcKey {
          continue
        }
        self.cache.removeValue(forKey: key)
      }
    }
  }

  /*

  @MainActor
  func getPaywallViewController(identifier: String) -> PaywallViewController? {
    let key = PaywallCacheLogic.key(
      identifier: identifier,
      locale: deviceLocaleString
    )
    return PaywallViewController.cache.first { $0.cacheKey == key }
  }

  @MainActor
  func removePaywallViewController(identifier: String) {
    if let viewController = getPaywallViewController(identifier: identifier) {
      PaywallViewController.cache.remove(viewController)
    }
  }

  @MainActor
  func removePaywallViewController(_ viewController: PaywallViewController) {
    PaywallViewController.cache.remove(viewController)
  }

  @MainActor
  func clearCache() {
    // don't remove the reference to a presented paywall
    for viewController in PaywallViewController.cache where !viewController.isActive {
      PaywallViewController.cache.remove(viewController)
    }
  }*/
}
