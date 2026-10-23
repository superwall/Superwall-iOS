//
//  MacDeviceInfo.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//

#if os(macOS)
import AppKit

/// The macOS sources for the device attributes UIKit reads from `UIDevice`,
/// `UIScreen` and trait collections.
enum MacDeviceInfo {
  private static let vendorIdLock = NSLock()

  /// The hardware model, such as `Mac14,2`, as `UIDevice.modelName` gives
  /// `iPhone15,2`.
  static let model: String = {
    var size = 0
    guard
      sysctlbyname("hw.model", nil, &size, nil, 0) == 0,
      size > 0
    else {
      return ""
    }
    var model = [CChar](repeating: 0, count: size)
    guard sysctlbyname("hw.model", &model, &size, nil, 0) == 0 else {
      return ""
    }
    return String(cString: model)
  }()

  /// An app-scoped installation identifier for SDK identity, not Apple's IDFV.
  static func vendorId(in defaults: UserDefaults = .standard) -> String {
    vendorIdLock.lock()
    defer { vendorIdLock.unlock() }
    let key = "com.superwall.vendorId"
    if let existing = defaults.string(forKey: key), !existing.isEmpty {
      return existing
    }
    let identifier = UUID().uuidString
    defaults.set(identifier, forKey: key)
    return identifier
  }

  /// The main screen's size in points and its backing scale.
  ///
  /// Reads `NSScreen` on the main thread, hopping there if needed. Unlike
  /// UIKit's screen, it's safe to read before the app has finished launching.
  static func screenMetrics() -> DeviceHelper.ScreenMetrics {
    let read = { () -> DeviceHelper.ScreenMetrics in
      guard let screen = NSScreen.main ?? NSScreen.screens.first else {
        return .placeholder
      }
      return DeviceHelper.ScreenMetrics(
        width: Int(screen.frame.width.rounded()),
        height: Int(screen.frame.height.rounded()),
        scale: Double(screen.backingScaleFactor)
      )
    }
    return Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)
  }

  /// The traits UIKit reports, read from AppKit.
  ///
  /// The appearance comes from the app, so an app that forces light or dark
  /// reports that. macOS has no Dynamic Type for apps, so every Mac is at the
  /// default text size, which iOS calls `large`.
  static func uiTraits() -> DeviceHelper.UITraits {
    let read = { () -> DeviceHelper.UITraits in
      DeviceHelper.UITraits(
        interfaceStyle: interfaceStyleToken(isDark: isDarkAppearance),
        fontSize: 16,
        fontScale: 1.0,
        preferredContentSizeCategory: "large"
      )
    }
    return Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)
  }

  /// Whether the app is drawing in a dark appearance. Before the application
  /// object exists, this falls back to the system setting.
  private static var isDarkAppearance: Bool {
    if let appearance = NSApplication.sharedApplication?.effectiveAppearance {
      return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
  }

  /// The same tokens ``DeviceHelper/interfaceStyleToken(for:)`` uses on iOS.
  /// They're a backend contract and must not change.
  static func interfaceStyleToken(isDark: Bool) -> String {
    return isDark ? "Dark" : "Light"
  }
}
#endif
