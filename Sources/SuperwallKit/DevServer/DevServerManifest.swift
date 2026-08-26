//
//  DevServerManifest.swift
//  SuperwallKit
//
//  The surface list a running `superwall dev` server exposes at
//  /device/manifest.json, used to map dashboard paywalls to locally
//  served paywall code when `SuperwallOptions/devMode` is on.
//

import Foundation

struct DevServerManifest: Decodable, Equatable {
  let surfaces: [DevServerSurface]

  /// Picks the local surface for a dashboard paywall: an explicit
  /// `superwall.lock` binding wins, otherwise a project with exactly one
  /// paywall serves it for everything.
  func surface(forPaywallDatabaseId databaseId: String) -> DevServerSurface? {
    if let bound = surfaces.first(where: { $0.paywallId == databaseId }) {
      return bound
    }
    let paywalls = surfaces.filter { $0.kind == "paywall" }
    if paywalls.count == 1 {
      return paywalls.first
    }
    return nil
  }

  func mountURL(for surface: DevServerSurface, base: URL) -> URL? {
    guard let resolved = URL(string: surface.url, relativeTo: base)?.absoluteURL else {
      return nil
    }
    // An absolute `url` resolves off `base` entirely, so a server reached at a
    // trusted address could otherwise name any origin it likes.
    guard
      resolved.scheme == base.scheme,
      resolved.host == base.host,
      resolved.port == base.port
    else {
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Ignoring dev server surface \(surface.id): its url \(surface.url) resolves to "
          + "\(resolved.absoluteString), which is off \(base.absoluteString)'s origin."
      )
      return nil
    }
    return resolved
  }
}
