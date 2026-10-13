//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 26/09/2024.
//
// swiftlint:disable identifier_name

#if os(iOS) || os(visionOS) || targetEnvironment(macCatalyst)
import UIKit
#elseif os(watchOS)
import UIKit
import WatchKit
#elseif os(macOS)
import AppKit
#endif

enum SystemInfo {
  static var applicationWillEnterForegroundNotification: Notification.Name {
    #if os(iOS) || os(visionOS)
    UIApplication.willEnterForegroundNotification
    #elseif os(macOS)
    NSApplication.willBecomeActiveNotification
    #elseif os(watchOS)
    Notification.Name.NSExtensionHostWillEnterForeground
    #endif
  }

  static var applicationDidBecomeActiveNotification: Notification.Name? {
    #if os(iOS) || os(visionOS) || targetEnvironment(macCatalyst)
    return UIApplication.didBecomeActiveNotification
    #elseif os(macOS)
    return NSApplication.didBecomeActiveNotification
    #elseif os(watchOS)
    if #available(watchOS 9, *) {
      return WKApplication.didBecomeActiveNotification
    } else {
      // Work around for "Symbol not found" dyld crashes on watchOS 8.0..<9.0
      return Notification.Name("WKApplicationDidBecomeActiveNotification")
    }
    #endif
  }

  static var applicationWillResignActiveNotification: Notification.Name {
    #if os(macOS)
    NSApplication.willResignActiveNotification
    #else
    UIApplication.willResignActiveNotification
    #endif
  }

  /// When the app stops being the one the user is working in.
  ///
  /// A Mac app doesn't move to the background, so on macOS this is when it
  /// resigns active, which is the last point the SDK can count on running
  /// before the user leaves it.
  static var applicationDidEnterBackgroundNotification: Notification.Name {
    #if os(macOS)
    NSApplication.didResignActiveNotification
    #else
    UIApplication.didEnterBackgroundNotification
    #endif
  }

  static var applicationWillTerminateNotification: Notification.Name {
    #if os(macOS)
    NSApplication.willTerminateNotification
    #else
    UIApplication.willTerminateNotification
    #endif
  }

  /// Where to send someone to turn notifications back on.
  ///
  /// iOS opens the app's own page in Settings. A Mac app has no page of its
  /// own, so this opens Notifications in System Settings, where the app is
  /// listed.
  static var notificationSettingsURL: URL? {
    #if os(macOS)
    URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
    #else
    URL(string: UIApplication.openSettingsURLString)
    #endif
  }
}
