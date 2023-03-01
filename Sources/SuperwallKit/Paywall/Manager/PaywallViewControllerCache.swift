//
//  PaywallCache.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

final class PaywallViewControllerCache: @unchecked Sendable {
  var activePaywallVcKey: String? {
    get {
      queue.sync { [weak self] in
        return self?._activePaywallVcKey
      }
    }
    set {
      queue.async { [weak self] in
        self?._activePaywallVcKey = newValue
      }
    }
  }
  private var _activePaywallVcKey: String?

  var activePaywallViewController: PaywallViewController? {
    guard let activePaywallVcKey = activePaywallVcKey else {
      return nil
    }

    return getPaywallViewController(forKey: activePaywallVcKey)
  }

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
        if key == self._activePaywallVcKey {
          continue
        }
        self.cache.removeValue(forKey: key)
      }
    }
  }
}
