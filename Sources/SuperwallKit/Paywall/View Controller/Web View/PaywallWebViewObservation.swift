//
//  PaywallWebViewObservation.swift
//  SuperwallKit
//

#if canImport(WebKit)
import Foundation
import WebKit

/// Returned by ``Superwall/addPaywallWebViewObserver(_:)``.
///
/// Keep it only if you want to stop observing later. Letting go of it doesn't
/// cancel the observer.
public final class PaywallWebViewObservation: Sendable {
  let id = UUID()

  init() {}

  /// Stops the observer from being called with any more paywall web views.
  @MainActor
  public func cancel() {
    PaywallWebViewObservers.remove(id: id)
  }
}

/// The observers called with each paywall web view as it's created.
@MainActor
enum PaywallWebViewObservers {
  private struct Entry {
    let id: UUID
    let observer: @MainActor (WKWebView) -> Void
  }

  /// Kept in the order they were added, which is the order they're called in.
  private static var entries: [Entry] = []

  static func add(
    _ observer: @escaping @MainActor (WKWebView) -> Void
  ) -> PaywallWebViewObservation {
    let observation = PaywallWebViewObservation()
    entries.append(Entry(id: observation.id, observer: observer))
    return observation
  }

  static func remove(id: UUID) {
    entries.removeAll { $0.id == id }
  }

  static func notify(_ webView: WKWebView) {
    // Loops over a copy, so an observer can add or cancel one while it runs.
    for entry in entries {
      entry.observer(webView)
    }
  }
}
#endif
