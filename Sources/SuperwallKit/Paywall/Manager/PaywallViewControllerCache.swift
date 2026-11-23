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

  /// The key of the cached paywall on screen. Setting a key marks the
  /// controller cached under it as on screen, or nothing if none is cached
  /// there. Setting `nil` marks it dismissed.
  var activePaywallVcKey: String? {
    get {
      store.read { $0.presentedKey }
    }
    set {
      if let newValue {
        store.dispatch(PaywallViewControllerCacheAction.presented(key: newValue), in: self)
        return
      }
      store.dispatch(PaywallViewControllerCacheAction.dismissed, in: self)
    }
  }

  var activePaywallViewController: PaywallViewController? {
    store.read { $0.presentedController }
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
