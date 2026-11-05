//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 26/09/2024.
//
// swiftlint:disable identifier_name

#if os(macOS)
import AppKit
#elseif os(watchOS)
import WatchKit
#else
import UIKit
#endif

enum SystemInfo {
  static var applicationWillEnterForegroundNotification: Notification.Name {
    #if os(macOS)
    NSApplication.willBecomeActiveNotification
    #elseif os(watchOS)
    WKExtension.applicationWillEnterForegroundNotification
    #else
    UIApplication.willEnterForegroundNotification
    #endif
  }

  static var applicationDidBecomeActiveNotification: Notification.Name? {
    #if os(macOS)
    return NSApplication.didBecomeActiveNotification
    #elseif os(watchOS)
    return WKExtension.applicationDidBecomeActiveNotification
    #else
    return UIApplication.didBecomeActiveNotification
    #endif
  }

  static var applicationWillResignActiveNotification: Notification.Name {
    #if os(macOS)
    NSApplication.willResignActiveNotification
    #elseif os(watchOS)
    WKExtension.applicationWillResignActiveNotification
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
    #elseif os(watchOS)
    WKExtension.applicationDidEnterBackgroundNotification
    #else
    UIApplication.didEnterBackgroundNotification
    #endif
  }

  /// When the app is about to quit. watchOS doesn't announce this, so there
  /// it's `nil`.
  static var applicationWillTerminateNotification: Notification.Name? {
    #if os(macOS)
    NSApplication.willTerminateNotification
    #elseif os(watchOS)
    nil
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
    #elseif os(watchOS)
    nil
    #else
    URL(string: UIApplication.openSettingsURLString)
    #endif
  }
}
