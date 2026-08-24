//
//  DevMode.swift
//  SuperwallKit
//
//  Dev mode is a development-only facility: it serves paywalls from a local
//  `superwall dev` server and simulates purchases. Shipping it to the App
//  Store would mean nobody could buy anything, so it is inert in production
//  no matter how the SDK was configured.
//

import Foundation

enum DevMode {
  private static var hasWarnedAboutProduction = false

  /// Whether this build is running somewhere dev mode is allowed. Overridable
  /// so tests can exercise the production path, which no simulator can produce.
  static var isSandboxEnvironment: () -> Bool = { DeviceHelper.isSandboxEnvironment }

  /// Whether dev mode should actually do anything right now: asked for, and
  /// running somewhere it is safe to (simulator, TestFlight, development).
  static func isActive(_ options: SuperwallOptions) -> Bool {
    guard options.isDevModeEnabled else {
      return false
    }
    guard isSandboxEnvironment() else {
      warnAboutProduction()
      return false
    }
    return true
  }

  private static func warnAboutProduction() {
    guard !hasWarnedAboutProduction else {
      return
    }
    hasWarnedAboutProduction = true
    Logger.debug(
      logLevel: .warn,
      scope: .superwallCore,
      message: "SuperwallOptions.devMode is on in a production build, so it is being ignored: "
        + "paywalls load their published versions and purchases are real. "
        + "Remove devMode before shipping."
    )
  }
}
