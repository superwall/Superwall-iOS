//
//  CustomerCenterViewModel+Dismissal.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

// MARK: - Visibility-driven dismissal

@available(iOS 15.0, *)
extension CustomerCenterViewModel {
  /// Call from any Customer Center surface's `onAppear` — the root view, and any screen it pushes
  /// itself. Pushing a screen removes the previous surface from the hierarchy without the Customer
  /// Center closing, so a count of concurrently visible surfaces (rather than a boolean) is what
  /// tracks nested pushes correctly. Also cancels any pending dismissal from a prior disappear.
  func surfaceDidAppear() {
    visibleSurfaceCount += 1
    isDismissalSuppressed = false
    dismissDebounceTask?.cancel()
    dismissDebounceTask = nil
  }

  /// Call from the matching `onDisappear` of any surface that called ``surfaceDidAppear()``.
  /// When the count drops to zero, waits out a debounce before dismissing: a push/pop transition can
  /// briefly have both surfaces on screen or neither, so one runloop turn can't tell "navigating
  /// within the Customer Center" from "the Customer Center was torn down". An appearance before the
  /// debounce elapses cancels it.
  func surfaceDidDisappear() {
    visibleSurfaceCount = max(0, visibleSurfaceCount - 1)
    scheduleDismissalIfNothingIsVisible()
  }

  /// Call when a surface knows it has been taken out of the hierarchy, not just covered. Lifts a
  /// veto from ``suppressDismissalUntilNextAppearance()`` that no appearance will now clear, and
  /// lets the visibility count decide again.
  ///
  /// A veto lasts until a surface appears, and a covered screen can be removed without appearing
  /// again. The host pushes a screen over the Customer Center, then pops back past both; or the
  /// Customer Center pushes its own detail screen, which covers the root, and the whole thing is
  /// dismissed from there. Left in place, the veto would keep the dismissal from ever being
  /// delivered.
  ///
  /// The same debounce still applies, so a surface that's only being moved — rehosted in another
  /// container, say — and reappears in time doesn't dismiss anything.
  func surfaceWasRemoved() {
    isDismissalSuppressed = false
    scheduleDismissalIfNothingIsVisible()
  }

  private func scheduleDismissalIfNothingIsVisible() {
    guard visibleSurfaceCount == 0, !isDismissalSuppressed else { return }
    dismissDebounceTask?.cancel()
    // Captures self strongly: on the SwiftUI sheet path the last `onDisappear` is immediately
    // followed by `@StateObject` releasing the view model, and a weak capture would let it
    // deallocate before the debounce elapses — silently dropping `didDismiss` and the
    // `customerCenterClose` event. The task only outlives the view by the debounce interval.
    dismissDebounceTask = Task { [dismissDebounceInterval] in
      try? await Task.sleep(nanoseconds: UInt64(dismissDebounceInterval * 1_000_000_000))
      guard !Task.isCancelled else { return }
      guard visibleSurfaceCount == 0 else { return }
      dismiss()
    }
  }

  /// Drops a dismissal the visibility count scheduled but hasn't delivered. The count can't tell a
  /// teardown from something being put on top, so it guesses; a host that knows better — a
  /// `CustomerCenterViewController` being covered rather than removed — vetoes the guess here.
  /// Left to fire, the premature ``dismiss()`` would latch and silence the genuine teardown.
  func cancelPendingDismissal() {
    dismissDebounceTask?.cancel()
    dismissDebounceTask = nil
  }

  /// The same veto, proof against the ordering it can't control.
  ///
  /// ``cancelPendingDismissal()`` only drops an already-armed dismissal, assuming SwiftUI has
  /// delivered `onDisappear` by the time `viewDidDisappear` runs — a moment Apple documents as
  /// view-type-dependent. Arriving a runloop turn later, it found nothing to cancel and armed
  /// unopposed. Suppressing until the next appearance covers both orderings. A genuine teardown
  /// is unaffected: the controllers deliver it through ``dismiss()`` directly, and SwiftUI screens
  /// report it through ``surfaceWasRemoved()``.
  func suppressDismissalUntilNextAppearance() {
    isDismissalSuppressed = true
    cancelPendingDismissal()
  }

  func dismiss() {
    guard !didDismiss else { return }
    didDismiss = true
    dismissDebounceTask?.cancel()
    dismissDebounceTask = nil
    callbacks.didDismiss?()
    Task { await dependencies.tracker.track(InternalSuperwallEvent.CustomerCenterClose()) }
  }
}
