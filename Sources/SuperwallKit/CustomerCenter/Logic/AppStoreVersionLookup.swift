//
//  AppStoreVersionLookup.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Foundation
import StoreKit

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
  private static let regionKey = "com.superwall.customerCenter.latestAppStoreVersionRegion"

  let bundleId: String?
  /// The device's two-letter region setting, used only when the App Store country can't be read.
  /// The two are configured independently, and it's the App Store country that decides which
  /// listing exists, so the region can name a store the app isn't published in.
  let regionCode: String?
  /// The App Store country as StoreKit reports it: three letters, such as `GBR`.
  let storefrontCountryCode: () async -> String?
  let defaults: UserDefaults
  let session: URLSession
  let now: () -> Date

  init(
    bundleId: String? = Bundle.main.bundleIdentifier,
    regionCode: String? = AppStoreVersionLookup.deviceRegionCode,
    storefrontCountryCode: @escaping () async -> String? = AppStoreVersionLookup.currentStorefrontCountryCode,
    defaults: UserDefaults = .standard,
    session: URLSession = .shared,
    now: @escaping () -> Date = Date.init
  ) {
    self.bundleId = bundleId
    self.regionCode = regionCode
    self.storefrontCountryCode = storefrontCountryCode
    self.defaults = defaults
    self.session = session
    self.now = now
  }

  /// Guarded rather than reading `Locale.regionCode` directly, which is deprecated at iOS 16 —
  /// `DeviceHelper.regionCode` makes the same split.
  static var deviceRegionCode: String? {
    if #available(iOS 16, *) {
      return Locale.autoupdatingCurrent.language.region?.identifier
    }
    return Locale.autoupdatingCurrent.regionCode
  }

  static func currentStorefrontCountryCode() async -> String? {
    if #available(iOS 15.0, *) {
      return await Storefront.current?.countryCode
    }
    return nil
  }

  /// The two-letter country to look the app up in: the App Store's, else the device region.
  /// Versions differ by country during a phased release, so asking the wrong store can report a
  /// version this device can't install.
  func lookupRegion() async -> String? {
    if let storefront = await storefrontCountryCode(),
      let alpha2 = CountryCode.alpha2(fromAlpha3: storefront) {
      return alpha2
    }
    return regionCode
  }

  func latestAppStoreVersion() async -> String? {
    let region = await lookupRegion()
    if let cached = cachedVersion(region: region) {
      return cached
    }
    guard let url = lookupURL(region: region) else {
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
          message: "No App Store listing found for bundle id \(bundleId ?? "nil") "
            + "in region \(region ?? "none"). The update banner won't show. If the app is "
            + "published elsewhere, that region is the likely reason. Set `latestAppVersion` to "
            + "warn without a lookup."
        )
        return nil
      }
      cache(version, region: region)
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

  private func lookupURL(region: String?) -> URL? {
    guard let bundleId, !bundleId.isEmpty else { return nil }
    var components = URLComponents(string: "https://itunes.apple.com/lookup")
    var items = [URLQueryItem(name: "bundleId", value: bundleId)]
    if let region, !region.isEmpty {
      items.append(URLQueryItem(name: "country", value: region))
    }
    components?.queryItems = items
    return components?.url
  }

  private func cachedVersion(region: String?) -> String? {
    guard
      let version = defaults.string(forKey: Self.versionKey),
      let fetchedAt = defaults.object(forKey: Self.fetchedAtKey) as? Date,
      now().timeIntervalSince(fetchedAt) < Self.cacheDuration,
      // A version is only the answer for the region it was fetched for. Without this, someone who
      // changes region is served the previous store's answer for the rest of the day — and that
      // is exactly when the answer is most likely to be wrong.
      defaults.string(forKey: Self.regionKey) == region
    else {
      return nil
    }
    return version
  }

  private func cache(_ version: String, region: String?) {
    defaults.set(version, forKey: Self.versionKey)
    defaults.set(now(), forKey: Self.fetchedAtKey)
    defaults.set(region, forKey: Self.regionKey)
  }
}
