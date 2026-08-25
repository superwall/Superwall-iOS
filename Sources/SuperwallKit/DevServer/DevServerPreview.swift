//
//  DevServerPreview.swift
//  SuperwallKit
//
//  Handles superwall_dev deep links: scanning the QR that `superwall dev`
//  prints opens this in-app picker of the dev server's local surfaces, and
//  selecting one presents it through the real paywall pipeline (which the
//  dev mode override then points at the local bytes).
//

import Combine
import Foundation
import UIKit

enum DevServerPreview {
  struct DeepLinkOutcome: Equatable {
    let base: URL
    let surfaceId: String?
  }

  static func outcomeForDeepLink(url: URL) -> DeepLinkOutcome? {
    guard
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let items = components.queryItems,
      let raw = items.first(where: { $0.name == "superwall_dev" })?.value,
      let base = URL(string: raw),
      base.scheme == "http" || base.scheme == "https"
    else {
      return nil
    }
    let surfaceId = items.first { $0.name == "superwall_dev_surface" }?.value
    return DeepLinkOutcome(base: base, surfaceId: surfaceId)
  }

  /// Whether `handle(url:)` would consume this URL: it parses, dev mode is on,
  /// and the base is a host `superwall dev` could actually have printed.
  static func canHandle(url: URL, options: SuperwallOptions) -> Bool {
    guard let outcome = outcomeForDeepLink(url: url) else {
      return false
    }
    return DevMode.isActive(options)
      && isTrustedBase(outcome.base, devServerURL: options.devServerURL)
  }

  /// A deep-link-supplied base may only name a host `superwall dev` ever
  /// prints — loopback, `.local`, or a private-network address — or the
  /// developer-supplied `devServerURL`, which is trusted input. Anything else
  /// is an arbitrary internet host that must not be handed the paywall
  /// pipeline's JS bridge.
  static func isTrustedBase(_ base: URL, devServerURL: URL?) -> Bool {
    if let devServerURL = devServerURL,
      base.scheme == devServerURL.scheme,
      base.host == devServerURL.host,
      base.port == devServerURL.port {
      return true
    }
    guard let host = base.host?.lowercased() else {
      return false
    }
    if host == "localhost" || host == "::1" || host.hasSuffix(".local") {
      return true
    }
    // Every component must be a numeric octet: compactMap alone would let a
    // DNS name like 10.0.0.1.evil.example.com pass as a private address.
    let components = host.split(separator: ".")
    let octets = components.compactMap { UInt8($0) }
    if components.count != 4 || octets.count != 4 {
      return false
    }
    switch (octets[0], octets[1]) {
    case (127, _), (10, _), (192, 168), (169, 254), (172, 16...31):
      return true
    default:
      return false
    }
  }

  static func handle(url: URL) -> Bool {
    guard let outcome = outcomeForDeepLink(url: url) else {
      return false
    }
    let options = Superwall.shared.options
    guard DevMode.isActive(options) else {
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Scanned a superwall dev link, but SuperwallOptions.devMode is off "
          + "in this build. Enable devMode to preview local paywalls in the app."
      )
      return false
    }
    guard isTrustedBase(outcome.base, devServerURL: options.devServerURL) else {
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Ignoring a superwall dev link pointing at \(outcome.base.absoluteString): "
          + "dev servers only run on localhost, .local hosts, or private-network addresses. "
          + "To use another host, set it as SuperwallOptions.devServerURL."
      )
      return false
    }
    Task { @MainActor in
      await open(outcome: outcome)
    }
    return true
  }

  @MainActor
  private static func open(outcome: DeepLinkOutcome) async {
    await DevServerLocator.shared.pin(base: outcome.base)
    guard
      let location = await DevServerLocator.shared.locate(
        devServerURL: Superwall.shared.options.devServerURL
      )
    else {
      return
    }

    guard let debugManager: DebugManager = Superwall.shared.dependencyContainer.debugManager else {
      return
    }
    debugManager.devServer = (base: location.base, surfaces: location.manifest.surfaces)
    await debugManager.launchDebugger(
      withPaywallId: nil,
      devSurfaceId: outcome.surfaceId ?? location.manifest.surfaces.first {
        $0.kind == "paywall"
      }?.id
    )
  }
}
