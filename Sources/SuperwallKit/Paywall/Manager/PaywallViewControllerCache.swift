//
//  PaywallCache.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//

#if canImport(WebKit)
import Foundation

/// Keeps paywall view controllers for reuse, and tracks which one is on
/// screen. Its state lives in a ``PaywallViewControllerCacheStore``.
///
/// View controllers the cache drops are let go of on the main thread, after
/// the store is unlocked, so their views are never torn down on another
/// thread or with the store locked. Reads go through
/// ``StateStore/read(_:)``, so a copy of the controllers never outlives the
/// lock and becomes the last owner of one that's removed meanwhile.
final class PaywallViewControllerCache: PaywallViewControllerCacheContext, @unchecked Sendable {
  let store = PaywallViewControllerCacheStore(initial: PaywallViewControllerCacheState())

  /// The key of the cached paywall on screen.
  var activePaywallVcKey: String? {
    store.read { $0.presentedKey }
  }

  var activePaywallViewController: PaywallViewController? {
    store.read { $0.presentedController }
  }

  /// `controller` appeared, with this key. It's only marked as on screen if
  /// it's the one cached under the key.
  func markPresented(_ controller: PaywallViewController, forKey key: String) {
    store.dispatch(
      PaywallViewControllerCacheAction.presented(controller, key: key),
      in: self
    )
  }

  /// `controller` was dismissed. Another paywall that's on screen stays
  /// marked as on screen.
  func markDismissed(_ controller: PaywallViewController) {
    store.dispatch(PaywallViewControllerCacheAction.dismissed(controller), in: self)
  }

  private let deviceLocaleString: String

  init(deviceLocaleString: String) {
    self.deviceLocaleString = deviceLocaleString
  }

  func save(_ paywallViewController: PaywallViewController, forKey key: String) {
    store.dispatch(
      PaywallViewControllerCacheAction.save(paywallViewController, key: key),
      in: self
    )
  }

  func getPaywallViewController(forKey key: String) -> PaywallViewController? {
    store.read { $0.controllers[key] }
  }

  func removePaywallViewController(forKey key: String) {
    store.dispatch(PaywallViewControllerCacheAction.remove(key: key), in: self)
  }

  /// Removes every view controller except the one on screen.
  func removeAll() {
    store.dispatch(PaywallViewControllerCacheAction.removeAllExceptPresented, in: self)
  }

  func release(_ released: ReleasedControllers) {
    if Thread.isMainThread {
      released.empty()
      return
    }
    DispatchQueue.main.async {
      released.empty()
    }
  }
}
#endif
