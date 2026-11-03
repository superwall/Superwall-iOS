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

/// Async work that runs on a ``SequentialStore``'s queue.
///
/// The context supplies every dependency the action needs, so tests can run
/// an action against a context built from mocks. Actions change state only
/// by passing a ``Reducer`` to ``SequentialStore/update(_:)``.
protocol StoreAction {
  associatedtype Context
  func execute(in context: Context) async
}

/// Work that runs synchronously on a ``SequentialStore``, for state whose
/// changes never wait on anything. See ``SequentialStore/dispatch(_:in:)``.
protocol SyncStoreAction {
  associatedtype Context
  func execute(in context: Context)
}
