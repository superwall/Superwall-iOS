//
//  AppStoreVersionLookup.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Foundation

/// Supplies the version currently published on the App Store, for the update banner to compare
/// the installed version against.
protocol CustomerCenterAppStoreVersionProviding {
  /// The published version, or `nil` when it can't be determined. Never throws: the banner is
  /// advisory, so every failure resolves to "don't show it".
  func latestAppStoreVersion() async -> String?
}

/// Reads the published version from Apple's public lookup endpoint.
///
/// Deliberately the public endpoint rather than App Store Connect: the Connect API authenticates
/// with a signed JWT, and the private key that signs it can't ship inside a client.
///
/// Known limitation — phased release. Apple rolls a release out over seven days, but the lookup
/// reports the new version to everyone the moment it's live. During that window some customers
/// are told to update to a build they can't install yet; tapping through lands them on a store
/// page still offering what they already have. Accepted rather than solved: the alternatives are
/// holding the banner back a fixed number of days (which delays it for genuinely stale installs
/// too) or not checking at all. Hosts who can't tolerate it should set `latestAppVersion` and
/// control the timing themselves.
struct AppStoreVersionLookup: CustomerCenterAppStoreVersionProviding {
  /// How long a looked-up version is trusted before being fetched again.
  static let cacheDuration: TimeInterval = 60 * 60 * 24

  private static let versionKey = "com.superwall.customerCenter.latestAppStoreVersion"
  private static let fetchedAtKey = "com.superwall.customerCenter.latestAppStoreVersionFetchedAt"

  let bundleId: String?
  /// Two-letter region for the storefront to query. Versions differ by region during a phased
  /// release, so asking for the wrong one can report a version this device can't install.
  let regionCode: String?
  let defaults: UserDefaults
  let session: URLSession
  let now: () -> Date

  init(
    bundleId: String? = Bundle.main.bundleIdentifier,
    regionCode: String? = Locale.current.regionCode,
    defaults: UserDefaults = .standard,
    session: URLSession = .shared,
    now: @escaping () -> Date = Date.init
  ) {
    self.bundleId = bundleId
    self.regionCode = regionCode
    self.defaults = defaults
    self.session = session
    self.now = now
  }

  func latestAppStoreVersion() async -> String? {
    if let cached = cachedVersion() {
      return cached
    }
    guard let url = lookupURL() else {
      Logger.debug(
        logLevel: .warn,
        scope: .customerCenter,
        message: "Can't check the App Store for updates: no bundle identifier."
      )
      return nil
    }
    do {
      let (data, response) = try await session.data(from: url)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        Logger.debug(
          logLevel: .warn,
          scope: .customerCenter,
          message: "App Store version lookup returned an unexpected response."
        )
        return nil
      }
      guard let version = Self.parseVersion(from: data) else {
        // An empty `results` array is the normal shape for an app that isn't on the store yet, or
        // a bundle identifier that doesn't match the published one. Worth saying out loud, since
        // silently never showing the banner is hard to diagnose.
        Logger.debug(
          logLevel: .warn,
          scope: .customerCenter,
          message: "No App Store listing found for bundle id \(bundleId ?? "nil"). "
            + "The update banner won't show. Set `latestAppVersion` to warn without a lookup."
        )
        return nil
      }
      cache(version)
      return version
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .customerCenter,
        message: "App Store version lookup failed.",
        error: error
      )
      return nil
    }
  }

  static func parseVersion(from data: Data) -> String? {
    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let results = json["results"] as? [[String: Any]],
      let version = results.first?["version"] as? String,
      !version.isEmpty
    else {
      return nil
    }
    return version
  }

  private func lookupURL() -> URL? {
    guard let bundleId, !bundleId.isEmpty else { return nil }
    var components = URLComponents(string: "https://itunes.apple.com/lookup")
    var items = [URLQueryItem(name: "bundleId", value: bundleId)]
    if let regionCode, !regionCode.isEmpty {
      items.append(URLQueryItem(name: "country", value: regionCode))
    }
    components?.queryItems = items
    return components?.url
  }

  private func cachedVersion() -> String? {
    guard
      let version = defaults.string(forKey: Self.versionKey),
      let fetchedAt = defaults.object(forKey: Self.fetchedAtKey) as? Date,
      now().timeIntervalSince(fetchedAt) < Self.cacheDuration
    else {
      return nil
    }
    return version
  }

  private func cache(_ version: String) {
    defaults.set(version, forKey: Self.versionKey)
    defaults.set(now(), forKey: Self.fetchedAtKey)
  }
}
