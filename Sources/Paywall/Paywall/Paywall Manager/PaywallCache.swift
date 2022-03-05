//
//  PaywallCache.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

final class PaywallCache {
  var values: Dictionary<String, SWPaywallViewController>.Values {
    return cache.values
  }
  private var cache: [String: SWPaywallViewController] = [:]

  private static func key(
    forIdentifier identifier: String?,
    event: EventData?
  ) -> String {
    let id = identifier ?? "$no_id"
    let name = event?.name ?? "$no_event"
    let locale = DeviceHelper.shared.locale

    return "\(id)_\(name)_\(locale)"
  }

  func getPaywall(
    forIdentifier identifier: String?,
    event: EventData?
  ) -> SWPaywallViewController? {
    let key = Self.key(
      forIdentifier: identifier,
      event: event
    )

    return cache[key]
  }

  func getPaywall(
    withKey key: String
  ) -> SWPaywallViewController? {
    return cache[key]
  }

  func savePaywall(
    _ viewController: SWPaywallViewController,
    withIdentifier identifier: String?,
    forEvent event: EventData?
  ) {
    let key = Self.key(
      forIdentifier: identifier,
      event: event
    )

    self.cache[key] = viewController

    if let identifier = identifier {
      self.cache[identifier + DeviceHelper.shared.locale] = viewController
    }
  }

  func removePaywall(
    withIdentifier identifier: String?,
    forEvent event: EventData?
  ) {
    let key = Self.key(
      forIdentifier: identifier,
      event: event
    )
    cache[key] = nil

    if let identifier = identifier {
      cache[identifier] = nil
    }
  }

  func removePaywall(withViewController viewController: SWPaywallViewController) {
    let keys = cache.allKeys(forValue: viewController)
    keys.forEach { cache[$0] = nil }
  }

  func clearCache() {
    cache.removeAll()
  }
}
