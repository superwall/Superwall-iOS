//
//  CustomCallbackRegistry.swift
//  SuperwallKit
//
//  Created by Ian Rumac on 2025.
//

import Foundation

/// Thread-safe registry for custom callback handlers, keyed by paywall identifier.
final class CustomCallbackRegistry: @unchecked Sendable {
  private var handlers: [String: (CustomCallback) async -> CustomCallbackResult] = [:]
  private let lock = NSLock()

  /// Registers a callback handler for a specific paywall identifier.
  func register(
    paywallIdentifier: String,
    handler: @escaping (CustomCallback) async -> CustomCallbackResult
  ) {
    lock.lock()
    defer { lock.unlock() }
    handlers[paywallIdentifier] = handler
  }

  /// Unregisters the callback handler for a specific paywall identifier.
  func unregister(paywallIdentifier: String) {
    lock.lock()
    defer { lock.unlock() }
    handlers.removeValue(forKey: paywallIdentifier)
  }

  /// Gets the callback handler for a specific paywall identifier.
  func getHandler(
    paywallIdentifier: String
  ) -> ((CustomCallback) async -> CustomCallbackResult)? {
    lock.lock()
    defer { lock.unlock() }
    return handlers[paywallIdentifier]
  }

  /// Clears all registered handlers.
  func clear() {
    lock.lock()
    defer { lock.unlock() }
    handlers.removeAll()
  }
}
