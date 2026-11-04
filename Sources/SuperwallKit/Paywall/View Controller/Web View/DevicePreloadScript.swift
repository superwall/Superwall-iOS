//
//  DevicePreloadScript.swift
//  SuperwallKit
//
//  Created by Superwall on 10/08/2026.
//

import Foundation

/// Builds the JavaScript injected into the paywall webview at document start.
///
/// The script sets `window.__SW_DEVICE_PRELOAD__` before any of the page's own
/// JavaScript runs, so paywall.js can resolve localized strings on its first
/// render instead of waiting for the full `template_variables` message, which
/// is delayed by receipt and product loading. The `template_variables` message
/// remains the source of truth and is sent unchanged.
enum DevicePreloadScript {
  /// Returns the script source, or `nil` if the payload can't be encoded.
  static func source(deviceLocale: String) -> String? {
    let payload = ["deviceLocale": deviceLocale]
    guard
      let data = try? JSONSerialization.data(withJSONObject: payload),
      let json = String(data: data, encoding: .utf8)
    else {
      return nil
    }
    return "window.__SW_DEVICE_PRELOAD__ = \(json);"
  }
}
