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
    let surfaceId = items.first(where: { $0.name == "superwall_dev_surface" })?.value
    return DeepLinkOutcome(base: base, surfaceId: surfaceId)
  }

  static func handle(url: URL) -> Bool {
    guard let outcome = outcomeForDeepLink(url: url) else {
      return false
    }
    Task { @MainActor in
      await open(outcome: outcome)
    }
    return true
  }

  @MainActor
  private static func open(outcome: DeepLinkOutcome) async {
    guard DevMode.isActive(Superwall.shared.options) else {
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Scanned a superwall dev link, but SuperwallOptions.devMode is off "
          + "in this build. Enable devMode to preview local paywalls in the app."
      )
      return
    }
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
      devSurfaceId: outcome.surfaceId ?? location.manifest.surfaces.first(where: {
        $0.kind == "paywall"
      })?.id
    )
  }
}
