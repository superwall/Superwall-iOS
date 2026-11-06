//
//  NSEvent+FirstClick.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//

#if os(macOS)
import AppKit

/// Tracks `touches_began` for the first click in the app, the macOS
/// counterpart of the `UIWindow.sendEvent` swizzle.
///
/// AppKit has a supported hook for this, so nothing is swizzled: a local
/// monitor sees each mouse-down before its window does, passes it on
/// untouched, and removes itself after the first one.
@MainActor
enum FirstClickMonitor {
  private static var monitor: Any?

  static func start() {
    guard monitor == nil else {
      return
    }
    monitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    ) { event in
      stop()
      Task {
        let touchesBegan = InternalSuperwallEvent.TouchesBegan()
        await Superwall.shared.track(touchesBegan)
      }
      return event
    }
  }

  private static func stop() {
    guard let monitor = monitor else {
      return
    }
    NSEvent.removeMonitor(monitor)
    self.monitor = nil
  }
}
#endif
