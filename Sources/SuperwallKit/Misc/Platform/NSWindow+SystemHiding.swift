//
//  NSWindow+SystemHiding.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 16/10/2026.
//
// AppKit tells a view controller it disappeared when its window is minimised or
// the app is hidden, and that it appeared again when the window comes back. The
// SDK's paywalls and sheets haven't left in either case, so they check this
// before treating a disappearance as a dismissal.

#if os(macOS)
import AppKit

enum SystemWindowHiding {
  /// Whether the app is on its way to being hidden. `NSApplication.isHidden`
  /// only turns true once its windows have gone.
  private(set) static var isAppHiding = false
  private static var observers: [NSObjectProtocol] = []

  /// Starts watching for the app being hidden. Call it before anything that
  /// checks ``NSWindow/isHiddenBySystem`` goes on screen.
  static func start() {
    guard observers.isEmpty else {
      return
    }
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: NSApplication.willHideNotification,
        object: nil,
        queue: .main
      ) { _ in
        isAppHiding = true
      },
      center.addObserver(
        forName: NSApplication.didUnhideNotification,
        object: nil,
        queue: .main
      ) { _ in
        isAppHiding = false
      }
    ]
  }
}

extension NSWindow {
  /// Whether the window is off screen, or on its way off, because it or a
  /// window it's attached to was minimised, or the app was hidden.
  var isHiddenBySystem: Bool {
    if SystemWindowHiding.isAppHiding || NSApplication.sharedApplication?.isHidden == true {
      return true
    }
    var window: NSWindow? = self
    while let current = window {
      if current.isMiniaturized {
        return true
      }
      window = current.sheetParent ?? current.parent
    }
    return false
  }

  /// Whether a window that's no longer visible was closed, rather than minimised
  /// or hidden with the app.
  var isClosedRatherThanHidden: Bool {
    return !isVisible && !isHiddenBySystem
  }
}
#endif
