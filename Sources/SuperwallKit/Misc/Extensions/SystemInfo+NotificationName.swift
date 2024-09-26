//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 26/09/2024.
//

#if os(iOS) || os(tvOS) || VISION_OS || targetEnvironment(macCatalyst)
import UIKit
#elseif os(watchOS)
import UIKit
import WatchKit
#elseif os(macOS)
import AppKit
#endif

enum SystemInfo {
  static var applicationWillEnterForegroundNotification: Notification.Name {
    #if os(iOS) || os(tvOS) || VISION_OS
    UIApplication.willEnterForegroundNotification
    #elseif os(macOS)
    NSApplication.willBecomeActiveNotification
    #elseif os(watchOS)
    Notification.Name.NSExtensionHostWillEnterForeground
    #endif
  }
}
