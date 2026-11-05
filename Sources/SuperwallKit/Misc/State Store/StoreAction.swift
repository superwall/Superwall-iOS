//
//  StoreAction.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//

import Foundation

/// A pure state transform: no side effects and no dispatch.
///
/// Reducers describe how state changes. Storage, network and tracking
/// belong in a ``StoreAction``.
protocol Reducer {
  associatedtype State
  func reduce(_ state: State) -> State
}

/// A change to a ``StateStore``'s state that runs while the store is locked.
///
/// The context supplies every dependency the action needs, so tests can run
/// an action against a context built from fakes. Actions change state only
/// by passing ``Reducer``s to ``StateStore/update(_:)``.
///
/// An action runs with the store locked, so it must not wait on anything:
/// no `queue.sync`, semaphores or calls into other objects that might.
/// Work that has to, such as resetting other parts of the SDK, goes in
/// ``StateStore/deferUntilUnlocked(_:)``, which runs once the lock is released.
/// Async work starts in a `Task`.
protocol StoreAction {
  associatedtype Context
  func execute(in context: Context)
}
