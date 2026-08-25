//
//  DevServerManifest.swift
//  SuperwallKit
//
//  The surface list a running `superwall dev` server exposes at
//  /device/manifest.json, used to map dashboard paywalls to locally
//  served paywall code when `SuperwallOptions/devMode` is on.
//

import Foundation

struct DevServerSurface: Decodable, Equatable {
  let kind: String
  let id: String
  let url: String
  let paywallId: String?
  let identifier: String?
  let products: [String: String]?
}

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
    return URL(string: surface.url, relativeTo: base)?.absoluteURL
  }
}

struct DevServerLocation: Equatable {
  let base: URL
  let manifest: DevServerManifest
}

enum DevServerCandidates {
  static let defaultPorts = 6100...6104

  /// The bases dev mode tries, in order: an explicit URL wins, otherwise
  /// localhost across the default port range `superwall dev` walks when
  /// its preferred port is taken.
  static func bases(devServerURL: URL?) -> [URL] {
    if let devServerURL = devServerURL {
      return [devServerURL]
    }
    return defaultPorts.compactMap { URL(string: "http://localhost:\($0)") }
  }
}

actor DevServerLocator {
  static let shared = DevServerLocator()

  private var cached: (location: DevServerLocation, fetchedAt: Date)?
  private var lastMissAt: Date?
  private var pinnedBase: URL?

  func pin(base: URL) {
    pinnedBase = base
    cached = nil
    lastMissAt = nil
  }

  func locate(devServerURL: URL?) async -> DevServerLocation? {
    if let cached = cached, Date().timeIntervalSince(cached.fetchedAt) < 2 {
      return cached.location
    }
    if let lastMissAt = lastMissAt, Date().timeIntervalSince(lastMissAt) < 5 {
      return nil
    }

    var bases = DevServerCandidates.bases(devServerURL: devServerURL)
    if let pinnedBase = pinnedBase {
      bases.removeAll { $0 == pinnedBase }
      bases.insert(pinnedBase, at: 0)
    }
    if let cached = cached {
      bases.removeAll { $0 == cached.location.base }
      bases.insert(cached.location.base, at: 0)
    }

    for base in bases {
      if let manifest = await fetchManifest(from: base) {
        let location = DevServerLocation(base: base, manifest: manifest)
        cached = (location, Date())
        lastMissAt = nil
        return location
      }
    }

    cached = nil
    lastMissAt = Date()
    Logger.debug(
      logLevel: .warn,
      scope: .superwallCore,
      message: "Dev mode is on but no superwall dev server was found at "
        + "\(bases.map { $0.absoluteString }.joined(separator: ", ")). "
        + "Paywalls will load their published versions. On a physical device, "
        + "set SuperwallOptions.devServerURL to the Device URL superwall dev prints."
    )
    return nil
  }

  private var hasWarnedAboutTransportSecurity = false

  /// App Transport Security blocks plain-http requests unless the app opts in,
  /// and the failure is otherwise indistinguishable from "no server there".
  private func warnIfBlockedByAppTransportSecurity(_ error: Error, base: URL) {
    let code = (error as NSError).code
    guard
      code == NSURLErrorAppTransportSecurityRequiresSecureConnection,
      !hasWarnedAboutTransportSecurity
    else {
      return
    }
    hasWarnedAboutTransportSecurity = true
    Logger.debug(
      logLevel: .error,
      scope: .superwallCore,
      message: "App Transport Security blocked \(base.absoluteString). Add this to the app's "
        + "Info.plist to preview local paywalls:\n"
        + "<key>NSAppTransportSecurity</key>\n<dict>\n"
        + "  <key>NSAllowsArbitraryLoadsInWebContent</key><true/>\n"
        + "  <key>NSAllowsLocalNetworking</key><true/>\n</dict>"
    )
  }

  private func fetchManifest(from base: URL) async -> DevServerManifest? {
    guard let manifestURL = URL(string: "/device/manifest.json", relativeTo: base) else {
      return nil
    }
    var request = URLRequest(url: manifestURL)
    request.timeoutInterval = 5
    request.cachePolicy = .reloadIgnoringLocalCacheData

    do {
      let data: Data = try await withCheckedThrowingContinuation { continuation in
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
          if let data = data {
            continuation.resume(returning: data)
          } else {
            continuation.resume(throwing: error ?? URLError(.badServerResponse))
          }
        }
        task.resume()
      }
      return try JSONDecoder().decode(DevServerManifest.self, from: data)
    } catch {
      warnIfBlockedByAppTransportSecurity(error, base: base)
      return nil
    }
  }
}
