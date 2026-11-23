//
//  PaywallViewControllerCacheState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

#if canImport(WebKit)
import Foundation

typealias PaywallViewControllerCacheStore = StateStore<
  PaywallViewControllerCacheContext,
  PaywallViewControllerCacheState
>

/// The paywall view controllers kept for reuse, and which one is on screen.
/// Changed only by ``PaywallViewControllerCacheUpdate`` reducers, which
/// ``PaywallViewControllerCacheAction``s apply.
///
/// Only ``PaywallViewControllerCacheUpdate`` can set the fields (through
/// ``applying(_:)``), and it keeps ``presentedKey``
/// pointing at a cached controller, so a controller saved later under the
/// same key is never taken for the one on screen.
struct PaywallViewControllerCacheState {
  /// The cached view controllers, keyed by ``PaywallCacheLogic/key(identifier:locale:)``.
  private(set) var controllers: [String: PaywallViewController] = [:]
  /// The key of the cached view controller on screen, if any. Always one of
  /// the keys in ``controllers``.
  private(set) var presentedKey: String?

  var presentedController: PaywallViewController? {
    guard let presentedKey else {
      return nil
    }
    return controllers[presentedKey]
  }
}

/// The ways ``PaywallViewControllerCacheState`` can change.
enum PaywallViewControllerCacheUpdate: Reducer {
  /// A controller was saved under a key, replacing any saved there before.
  /// Replacing the controller on screen means the one on screen is no longer
  /// cached.
  case saved(PaywallViewController, key: String)
  /// The controllers under these keys were removed. Removing the one on
  /// screen means nothing cached is on screen.
  case removed(keys: Set<String>)
  /// The controller under a key appeared. Nothing cached is on screen if no
  /// controller is cached under it.
  case presented(key: String)
  /// The controller on screen was dismissed.
  case dismissed

  func reduce(_ state: PaywallViewControllerCacheState) -> PaywallViewControllerCacheState {
    state.applying(self)
  }
}

extension PaywallViewControllerCacheState {
  /// The state after `update`. The only place the fields change.
  func applying(_ update: PaywallViewControllerCacheUpdate) -> PaywallViewControllerCacheState {
    var state = self
    switch update {
    case let .saved(controller, key):
      if state.presentedKey == key,
        state.controllers[key] !== controller {
        state.presentedKey = nil
      }
      state.controllers[key] = controller
    case .removed(let keys):
      for key in keys {
        state.controllers.removeValue(forKey: key)
      }
      if let presentedKey = state.presentedKey,
        keys.contains(presentedKey) {
        state.presentedKey = nil
      }
    case .presented(let key):
      state.presentedKey = state.controllers[key] == nil ? nil : key
    case .dismissed:
      state.presentedKey = nil
    }
    return state
  }
}

/// Everything the cache's actions need. ``PaywallViewControllerCache``
/// provides it in the SDK, and tests provide a fake.
protocol PaywallViewControllerCacheContext: AnyObject {
  var store: PaywallViewControllerCacheStore { get }

  /// Lets go of view controllers the cache no longer holds. Called with the
  /// store unlocked. The controllers must be let go of on the main thread,
  /// since dropping the last reference to one tears down its views.
  func release(_ released: ReleasedControllers)
}

/// View controllers the cache has dropped, held until they're released on
/// the main thread.
///
/// Only this box holds them once the store has dropped them, so whoever
/// empties it lets go of the last reference the cache had.
final class ReleasedControllers: @unchecked Sendable {
  private(set) var controllers: [PaywallViewController]

  init(_ controllers: [PaywallViewController]) {
    self.controllers = controllers
  }

  /// Empties the box.
  func empty() {
    controllers = []
  }
}

/// Every change to the cache. Each runs with the store locked, and releases
/// the controllers it drops once the store is unlocked.
enum PaywallViewControllerCacheAction: StoreAction {
  /// Saves a view controller, replacing any under the same key.
  case save(PaywallViewController, key: String)
  /// Removes the view controller under a key.
  case remove(key: String)
  /// Removes every view controller but the one on screen.
  case removeAllExceptPresented
  /// The view controller under a key appeared.
  case presented(key: String)
  /// The view controller on screen was dismissed.
  case dismissed

  func execute(in context: PaywallViewControllerCacheContext) {
    let state = context.store.state
    let update: PaywallViewControllerCacheUpdate
    var dropped: [PaywallViewController] = []

    switch self {
    case let .save(controller, key):
      update = .saved(controller, key: key)
      if let old = state.controllers[key],
        old !== controller {
        dropped = [old]
      }
    case .remove(let key):
      update = .removed(keys: [key])
      dropped = state.controllers[key].map { [$0] } ?? []
    case .removeAllExceptPresented:
      let keys = Set(state.controllers.keys.filter { $0 != state.presentedKey })
      update = .removed(keys: keys)
      dropped = keys.compactMap { state.controllers[$0] }
    case .presented(let key):
      update = .presented(key: key)
    case .dismissed:
      update = .dismissed
    }

    context.store.update(update)

    if dropped.isEmpty {
      return
    }
    let released = ReleasedControllers(dropped)
    context.store.deferUntilUnlocked {
      context.release(released)
    }
  }
}
#endif
