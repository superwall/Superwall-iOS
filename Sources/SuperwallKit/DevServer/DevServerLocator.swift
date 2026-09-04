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
  private var hasWarnedAboutTransportSecurity = false

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
        + "set SuperwallOptions.devServer to the Device URL superwall dev prints."
    )
    return nil
  }

  /// App Transport Security blocks plain-http requests unless the app opts in,
  /// and the failure is otherwise indistinguishable from "no server there".
  private func warnIfBlockedByAppTransportSecurity(_ error: Error, base: URL) {
    let code = (error as NSError).code
    guard code == NSURLErrorAppTransportSecurityRequiresSecureConnection else {
      return
    }
    if hasWarnedAboutTransportSecurity {
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

  /// Logs a body that carries `surfaces` but wouldn't decode.
  ///
  /// The probe walks several ports and can't know what is listening on each,
  /// so this neither claims the responder is a dev server nor stays silent
  /// when it plainly is one whose manifest this SDK can't read.
  private func logUnreadableManifest(data: Data, base: URL, error: Error) {
    let json = try? JSONSerialization.jsonObject(with: data)
    guard let object = json as? [String: Any],
      object["surfaces"] != nil
    else {
      // Not a manifest at all — something else answered. The port walk moves
      // on, and `locate` reports it if nothing else turns up.
      return
    }
    Logger.debug(
      logLevel: .error,
      scope: .superwallCore,
      message: "Something at \(base.absoluteString) answered /device/manifest.json with a "
        + "manifest this SDK couldn't read. Those paywalls will load their published "
        + "versions. Check that superwall dev and SuperwallKit are on compatible versions.",
      error: error
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
      let (data, response): (Data, URLResponse?) = try await withCheckedThrowingContinuation { continuation in
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
          if let data = data {
            continuation.resume(returning: (data, response))
          } else {
            continuation.resume(throwing: error ?? URLError(.badServerResponse))
          }
        }
        task.resume()
      }
      // Something else on this port may answer an unknown path with a JSON
      // error body, so the status has to rule that out before the body does.
      if let http = response as? HTTPURLResponse,
        !(200..<300).contains(http.statusCode) {
        return nil
      }
      do {
        return try JSONDecoder().decode(DevServerManifest.self, from: data)
      } catch {
        logUnreadableManifest(data: data, base: base, error: error)
        return nil
      }
    } catch {
      warnIfBlockedByAppTransportSecurity(error, base: base)
      return nil
    }
  }
}
