//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/07/2022.
//
// swiftlint:disable line_length

import Foundation

public extension Paywall {
  /// WARNING: Determines which network environment your SDK should use. Defaults to latest. You should under no circumstance change this unless you received the go-ahead from the Superwall team.
  @available(*, deprecated, message: "Please define this in a PaywallOptions object and pass it to Paywall.configure(apiKey:userId:delegate:options:)")
  static var networkEnvironment: PaywallOptions.PaywallNetworkEnvironment = .release {
    didSet {
      Paywall.options.networkEnvironment = Paywall.networkEnvironment
    }
  }

  /// Defines the title of the alert presented to the end user when restoring transactions fails. Defaults to `No Subscription Found`.
  @available(*, deprecated, message: "Please define this in a PaywallOptions object and pass it to Paywall.configure(apiKey:userId:delegate:options:)")
  static var restoreFailedTitleString = "No Subscription Found" {
    didSet {
      Paywall.options.restoreFailed.title = Paywall.restoreFailedTitleString
    }
  }

  /// Defines the message of the alert presented to the end user when restoring transactions fails. Defaults to `We couldn't find an active subscription for your account.`
  @available(*, deprecated, message: "Please define this in a PaywallOptions object and pass it to Paywall.configure(apiKey:userId:delegate:options:)")
  static var restoreFailedMessageString = "We couldn't find an active subscription for your account." {
    didSet {
      Paywall.options.restoreFailed.message = Paywall.restoreFailedMessageString
    }
  }

  /// Defines the close button title of the alert presented to the end user when restoring transactions fails. Defaults to `Okay`.
  @available(*, deprecated, message: "Please define this in a PaywallOptions object and pass it to Paywall.configure(apiKey:userId:delegate:options:)")
  static var restoreFailedCloseButtonString = "Okay" {
    didSet {
      Paywall.options.restoreFailed.closeButtonTitle = Paywall.restoreFailedCloseButtonString
    }
  }

  /// Forwards events from the game controller to the paywall. Defaults to `false`.
  ///
  /// Set this to `true` to forward events from the Game Controller to the Paywall via ``Paywall/Paywall/gamepadValueChanged(gamepad:element:)``.
  @available(*, deprecated, message: "Please define this in a PaywallOptions object and pass it to Paywall.configure(apiKey:userId:delegate:options:)")
  static var isGameControllerEnabled = false {
    didSet {
      Paywall.options.isGameControllerEnabled = Paywall.isGameControllerEnabled
    }
  }

  /// Animates paywall presentation. Defaults to `true`.
  ///
  /// Set this to `false` to globally disable paywall presentation animations.
  @available(*, deprecated, message: "Either set the Presentation Style on the Superwall dashboard to No Animation or, for a trigger-specific override, set presentationStyleOverride on Paywall.trigger().")
  static var shouldAnimatePaywallPresentation = true

  /// Animates paywall dismissal. Defaults to `true`.
  ///
  /// Set this to `false` to globally disable paywall dismissal animations.
  @available(*, deprecated, message: "Either set the Presentation Style on the Superwall dashboard to No Animation or, for a trigger-specific override, set presentationStyleOverride on Paywall.trigger().")
  static var shouldAnimatePaywallDismissal = true

  /// Pre-loads and caches triggers and their associated paywalls and products when you initialize the SDK via ``Paywall/Paywall/configure(apiKey:userId:delegate:options:)``. Defaults to `true`.
  ///
  /// Set this to `false` to load and cache triggers in a just-in-time fashion.
  @available(*, deprecated, message: "Please instead define shouldPreloadPaywalls in a PaywallOptions object and pass it to Paywall.configure(apiKey:userId:delegate:options:)")
  static var shouldPreloadTriggers = true {
    didSet {
      Paywall.options.shouldPreloadPaywalls = Paywall.shouldPreloadTriggers
    }
  }

  /// This is no longer used to control log levels.
  @available(*, deprecated, message: "This has been replaced with logLevel, which you set in a PaywallOptions object and pass to Paywall.configure(apiKey:userId:delegate:options:)")
  @objc static var debugMode = false {
    didSet {
      Paywall.options.logging.level = Paywall.debugMode ? .debug : .warn
    }
  }

  /// Defines the minimum log level to print to the console. Defaults to `warn`.
  @available(*, deprecated, message: "Please define this in a PaywallOptions object and pass it to Paywall.configure(apiKey:userId:delegate:options:)")
  static var logLevel: LogLevel? = .warn {
    didSet {
      Paywall.options.logging.level = Paywall.logLevel
    }
  }

  /// Defines the scope of logs to print to the console. Defaults to .all
  @available(*, deprecated, message: "Please define this in a PaywallOptions object and pass it to Paywall.configure(apiKey:userId:delegate:options:)")
  static var logScopes: Set<LogScope> = [.all] {
    didSet {
      Paywall.options.logging.scopes = Paywall.logScopes
    }
  }

  /// Automatically dismisses the paywall when a product is purchased or restored. Defaults to `true`.
  ///
  /// Set this to `false` to prevent the paywall from dismissing on purchase/restore.
  @available(*, deprecated, message: "Please define this in a PaywallOptions object and pass it to Paywall.configure(apiKey:userId:delegate:options:)")
  static var automaticallyDismiss = true {
    didSet {
      Paywall.options.automaticallyDismiss = Paywall.automaticallyDismiss
    }
  }
}
