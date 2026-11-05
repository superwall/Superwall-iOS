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
struct PaywallViewControllerCacheState {
  /// The cached view controllers, keyed by ``PaywallCacheLogic/key(identifier:locale:)``.
  var controllers: [String: PaywallViewController] = [:]
  /// The key of the view controller on screen, if any.
  var activeKey: String?

  var activeController: PaywallViewController? {
    guard let activeKey else {
      return nil
    }
    return controllers[activeKey]
  }
}

/// The ways ``PaywallViewControllerCacheState`` can change.
enum PaywallViewControllerCacheUpdate: Reducer {
  case save(PaywallViewController, key: String)
  case remove(keys: Set<String>)
  case activeKey(String?)

  func reduce(_ state: PaywallViewControllerCacheState) -> PaywallViewControllerCacheState {
    var state = state
    switch self {
    case let .save(controller, key):
      state.controllers[key] = controller
    case .remove(let keys):
      for key in keys {
        state.controllers.removeValue(forKey: key)
      }
    case .activeKey(let key):
      state.activeKey = key
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

/// Changes to the cache that drop view controllers. They run with the store
/// locked, and release what they drop once it's unlocked.
enum PaywallViewControllerCacheAction: StoreAction {
  /// Saves a view controller, replacing any under the same key.
  case save(PaywallViewController, key: String)
  /// Removes the view controller under a key.
  case remove(key: String)
  /// Removes every view controller but the one on screen.
  case removeAllExceptActive

  func execute(in context: PaywallViewControllerCacheContext) {
    let state = context.store.state
    let keys: Set<String>
    let update: PaywallViewControllerCacheUpdate

    switch self {
    case let .save(controller, key):
      keys = [key]
      update = .save(controller, key: key)
    case .remove(let key):
      keys = [key]
      update = .remove(keys: keys)
    case .removeAllExceptActive:
      keys = Set(state.controllers.keys.filter { $0 != state.activeKey })
      update = .remove(keys: keys)
    }

    var dropped: [PaywallViewController] = []
    for key in keys {
      guard let controller = state.controllers[key] else {
        continue
      }
      if case let .save(newController, _) = self,
        newController === controller {
        continue
      }
      dropped.append(controller)
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
