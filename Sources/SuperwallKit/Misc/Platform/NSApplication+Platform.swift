//
//  NSApplication+Platform.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//
// The AppKit side of the UIKit helpers the SDK leans on, given the same names
// so shared code calls one API on every platform.

#if os(macOS)
import AppKit

/// The app's activity, mirroring `UIApplication.State`.
///
/// A Mac app keeps running when it isn't frontmost, so it's never `background`:
/// work that waits for the app to come back would otherwise stall whenever the
/// user switches to another app.
enum ApplicationState {
  case active
  case inactive
  case background
}

extension NSApplication {
  /// The shared application, or `nil` before `NSApplication.shared` has been
  /// created, as in a command line tool or a unit test host without an app.
  static var sharedApplication: NSApplication? {
    return NSApp
  }

  var applicationState: ApplicationState {
    return isActive ? .active : .inactive
  }

  /// The window the user is working in: the key window, then the main window,
  /// then the first visible window that isn't a panel.
  var activeWindow: NSWindow? {
    if let keyWindow = keyWindow,
      !(keyWindow is NSPanel) {
      return keyWindow
    }
    if let mainWindow = mainWindow {
      return mainWindow
    }
    return windows.first { $0.isVisible && !($0 is NSPanel) }
  }

  /// Opens a URL in the app the user has chosen to handle it.
  func open(_ url: URL) {
    NSWorkspace.shared.open(url)
  }

  /// Whether any app on the Mac can open the URL.
  func canOpenURL(_ url: URL) -> Bool {
    return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
  }
}

extension NSWindow {
  /// The view controller at the root of the window, under UIKit's name: its
  /// content view controller, or what a window the SDK made presents from.
  var rootViewController: NSViewController? {
    return (self as? PaywallHostWindow)?.host ?? contentViewController
  }
}

extension NSViewController {
  /// The view controller at the top of the active window: its content view
  /// controller, or the last one presented over it, including any sheet the
  /// window shows.
  @MainActor
  static var topMostViewController: NSViewController? {
    guard let sharedApplication = NSApplication.sharedApplication else {
      return nil
    }
    var topViewController = sharedApplication.activeWindow?.rootViewController
    while let current = topViewController {
      if let presented = current.presentedViewControllers?.last {
        topViewController = presented
      } else if let sheet = current.view.window?.attachedSheet?.contentViewController,
        sheet !== current {
        topViewController = sheet
      } else {
        break
      }
    }
    return topViewController
  }

  /// A view controller with an empty view. One without a nib has no view to
  /// load before macOS 14.
  static func blank() -> NSViewController {
    return BlankViewController()
  }
}

private final class BlankViewController: NSViewController {
  override func loadView() {
    view = NSView()
  }
}
#endif
