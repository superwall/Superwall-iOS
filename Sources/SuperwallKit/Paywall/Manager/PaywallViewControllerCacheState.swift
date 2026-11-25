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
  /// This controller appeared, with this key. Nothing cached is on screen if
  /// another controller is cached under the key, or none is.
  case controllerPresented(PaywallViewController, key: String)
  /// The controller on screen was dismissed.
  case dismissed
  /// This controller was dismissed. Does nothing if another controller is the
  /// one on screen, as when one paywall is shown while another finishes
  /// closing.
  case controllerDismissed(PaywallViewController)

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
    case let .controllerPresented(controller, key):
      state.presentedKey = state.controllers[key] === controller ? key : nil
    case .dismissed:
      state.presentedKey = nil
    case .controllerDismissed(let controller):
      if state.presentedController === controller {
        state.presentedKey = nil
      }
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
  /// This view controller appeared, with this key.
  case controllerPresented(PaywallViewController, key: String)
  /// The view controller on screen was dismissed.
  case dismissed
  /// This view controller was dismissed.
  case controllerDismissed(PaywallViewController)

  func execute(in context: PaywallViewControllerCacheContext) {
    let update: PaywallViewControllerCacheUpdate
    var dropped: [PaywallViewController] = []

    switch self {
    case let .save(controller, key):
      update = .saved(controller, key: key)
      if let old = context.store.read({ $0.controllers[key] }),
        old !== controller {
        dropped = [old]
      }
    case .remove(let key):
      update = .removed(keys: [key])
      dropped = context.store.read { $0.controllers[key] }.map { [$0] } ?? []
    case .removeAllExceptPresented:
      let removed = context.store.read { state in
        state.controllers.filter { $0.key != state.presentedKey }
      }
      update = .removed(keys: Set(removed.keys))
      dropped = Array(removed.values)
    case .presented(let key):
      update = .presented(key: key)
    case let .controllerPresented(controller, key):
      update = .controllerPresented(controller, key: key)
    case .dismissed:
      update = .dismissed
    case .controllerDismissed(let controller):
      update = .controllerDismissed(controller)
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
