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

  private enum CodingKeys: String, CodingKey {
    case surfaces
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Per-element decoding: the CLI writing this manifest versions separately
    // from the SDK, so one surface the SDK can't read must not take down the
    // surfaces it can.
    // Required: `surfaces` is the only thing that tells this JSON apart from
    // whatever else might answer on a candidate port, so a body without it
    // must fail rather than end the port walk. A project with no surfaces
    // still sends `{"surfaces": []}`.
    let decoded = try container.decode([Throwable<DevServerSurface>].self, forKey: .surfaces)
    surfaces = decoded.compactMap { try? $0.result.get() }

    let dropped = decoded.count - surfaces.count
    if dropped > 0 {
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Skipped \(dropped) of \(decoded.count) dev server surfaces that couldn't be "
          + "read. Those paywalls will load their published versions."
      )
    }
  }

  init(surfaces: [DevServerSurface]) {
    self.surfaces = surfaces
  }

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
