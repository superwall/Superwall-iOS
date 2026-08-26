//
//  DevServerLocator.swift
//  SuperwallKit
//
//  Finds the running `superwall dev` server by probing the candidate
//  bases for /device/manifest.json, with short-lived caching of both
//  hits and misses so paywall requests don't hammer the network.
//

import Foundation

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
    if let cached = cached,
      Date().timeIntervalSince(cached.fetchedAt) < 2 {
      return cached.location
    }
    if let lastMissAt = lastMissAt,
      Date().timeIntervalSince(lastMissAt) < 5 {
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
