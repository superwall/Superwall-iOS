//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/03/2025.
//
// swiftlint:disable strict_fileprivate

import Foundation
import Combine

final class DeepLinkRouter {
  private unowned let webEntitlementRedeemer: WebEntitlementRedeemer
  private unowned let debugManager: DebugManager
  private unowned let configManager: ConfigManager
  private static var pendingDeepLink: URL?

  /// Tracks an event. Replaced in tests to observe what's tracked.
  var trackEvent: (Trackable) async -> Void = { event in
    _ = await Superwall.shared.track(event)
  }

  /// The presented paywall's info, if a paywall is presented. Replaced in tests.
  var presentedPaywallInfo: () async -> PaywallInfo? = {
    await Superwall.shared.paywallViewController?.info
  }

  init(
    webEntitlementRedeemer: WebEntitlementRedeemer,
    debugManager: DebugManager,
    configManager: ConfigManager
  ) {
    self.webEntitlementRedeemer = webEntitlementRedeemer
    self.debugManager = debugManager
    self.configManager = configManager

    listenToConfig()
  }

  @discardableResult
  func route(url: URL) -> Bool {
    // A return link only brings the app back from a Superwall web flow. The
    // flow's paywall finishes the job itself, so the link must not be tracked
    // as a deep link: `deepLink_open` dismisses the presented paywall.
    if url.isSuperwallReturnLink {
      // The paywall that opened the checkout takes its waiting screen out of sight at once.
      let userInfo = url.superwallReturnReason.map { ["reason": $0] }
      if Thread.isMainThread {
        NotificationCenter.default.post(
          name: .superwallReturnLinkOpened,
          object: nil,
          userInfo: userInfo
        )
      } else {
        DispatchQueue.main.async {
          NotificationCenter.default.post(
            name: .superwallReturnLinkOpened,
            object: nil,
            userInfo: userInfo
          )
        }
      }
      // Tracked as `teleport_return` instead, with the presented paywall's info.
      let trackEvent = self.trackEvent
      let presentedPaywallInfo = self.presentedPaywallInfo
      Task {
        let paywallInfo = await presentedPaywallInfo()
        await trackEvent(
          InternalSuperwallEvent.TeleportReturn(
            paywallInfo: paywallInfo,
            reason: url.superwallReturnReason
          )
        )
      }
      return true
    }

    // Check if the URL matches the expected web2app format
    if let code = url.redeemableCode {
      Task {
        await webEntitlementRedeemer.redeem(.code(code))
      }
      return true
    }

    let deepLinkUrl: URL
    let isSuperwallDeepLink = url.isSuperwallDeepLink

    if isSuperwallDeepLink {
      deepLinkUrl = url.superwallDeepLinkMappedURL

      Task { @MainActor in
        Superwall.shared.dependencyContainer.delegateAdapter.handleSuperwallDeepLink(
          url,
          pathComponents: url.superwallDeepLinkPathComponents,
          queryParameters: url.queryParameters
        )
      }
    } else {
      deepLinkUrl = url
    }

    let trackEvent = self.trackEvent
    Task {
      await trackEvent(InternalSuperwallEvent.DeepLink(url: deepLinkUrl))
    }

    // Check if this is a debug URL
    if debugManager.handle(deepLinkUrl: deepLinkUrl) {
      return true
    }

    if DevServerPreview.handle(url: deepLinkUrl) {
      return true
    }

    // Return true for Superwall deep links (we handled it above)
    if isSuperwallDeepLink {
      return true
    }

    // Return true if there's a deepLink_open trigger configured
    if configManager.triggersByPlacementName[SuperwallEventObjc.deepLink.description] != nil {
      return true
    }

    return false
  }

  private func listenToConfig() {
    configManager.configState
      .subscribe(
        Subscribers.Sink(
          receiveCompletion: { _ in },
          receiveValue: { [weak self] state in
            switch state {
            case .retrieved:
              if let deepLink = Self.pendingDeepLink {
                self?.route(url: deepLink)
                Self.pendingDeepLink = nil
              }
            default:
              break
            }
          }
        )
      )
  }

  /// Stores the deep link until it can be handled.
  ///
  /// Called when `handleDeepLink` is invoked before Superwall configuration completes.
  /// The URL is always stored so it can be processed once config loads, but the return
  /// value indicates whether Superwall will definitely handle this URL.
  ///
  /// - Note: The URL is always stored regardless of return value because the fresh config
  ///   might have a `deepLink_open` trigger even if cached config doesn't. This ensures
  ///   deep links aren't lost during app launch. If the URL isn't a Superwall URL,
  ///   returning `false` allows other handlers in a handler chain to process it.
  ///
  /// - Parameter url: The deep link URL to store.
  /// - Returns: `true` if the URL is a Superwall URL that will be handled, `false` otherwise.
  static func storeDeepLink(_ url: URL) -> Bool {
    // Always store the URL - the fresh config might have deepLink_open trigger
    // even if cached config doesn't
    pendingDeepLink = url

    // Only return true if we're confident Superwall will handle this URL
    return isSuperwallURL(url)
  }

  /// Checks if the URL is one that Superwall will handle.
  private static func isSuperwallURL(_ url: URL) -> Bool {
    // Superwall universal links (*.superwall.app/app-link/*)
    if url.isSuperwallDeepLink {
      return true
    }

    // Redemption codes
    if url.redeemableCode != nil {
      return true
    }

    // Return links from Superwall web flows
    if url.isSuperwallReturnLink {
      return true
    }

    // Debug/preview URLs
    if DebugManager.outcomeForDeepLink(url: url) != nil {
      return true
    }

    // Dev links count as Superwall's only while dev mode is verifiably on.
    // Before initialization there are no options to check (and touching
    // `Superwall.shared` would assert), so don't claim the link — it is
    // stored above and routed again once config arrives.
    if Superwall.isInitialized,
      DevServerPreview.canHandle(url: url, options: Superwall.shared.options) {
      return true
    }

    // Check cached config for deepLink_open trigger
    let cache = Cache()
    if let config = cache.read(LatestConfig.self) {
      let triggers = ConfigLogic.getTriggersByPlacementName(from: config.triggers)
      if triggers[SuperwallEventObjc.deepLink.description] != nil {
        return true
      }
    }

    return false
  }
}

extension URL {
  /// Whether this link brings the user back to the app from a Superwall web
  /// flow, such as a paywall's checkout page. Matches
  /// `scheme://superwall/return` and
  /// `https://<subdomain>.superwall.app/app-link/superwall/return`.
  var isSuperwallReturnLink: Bool {
    if scheme != "http",
      scheme != "https",
      host == "superwall",
      path == "/return" {
      return true
    }

    if let host,
      host.hasSuffix(".superwall.link")
        || host.hasSuffix(".superwall.app")
        || host.hasSuffix(".superwallapp.dev"),
      path == "/app-link/superwall/return" {
      return true
    }

    return false
  }

  /// Why the web flow sent the user back, when it says: `purchased` after paying on the checkout
  /// page, `closed` when they closed it instead.
  var superwallReturnReason: String? {
    URLComponents(url: self, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first { $0.name == "reason" }?
      .value
  }

  /// The web checkout code to redeem given a Superwall deep link format.
  var redeemableCode: String? {
    let urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: false)

    if host == "superwall",
      path == "/redeem",
      let code = urlComponents?.queryItems?.first(where: { $0.name == "code" })?.value {
      return code
    }

    if let host,
      host.hasSuffix("superwall.app") || host.hasSuffix("superwallapp.dev"),
      path == "/app-link/superwall/redeem",
      let code = urlComponents?.queryItems?.first(where: { $0.name == "code" })?.value {
      return code
    }

    return nil
  }

  /// Returns `true` if the `URL` matches the expected Superwall deep link format.
  var isSuperwallDeepLink: Bool {
    guard
      let host = self.host,
      host.hasSuffix(".superwall.app") || host.hasSuffix(".superwallapp.dev")
    else {
      return false
    }
    return path.hasPrefix("/app-link/")
  }

  /// The path components after the `app-link` component in the URL.
  ///
  /// - Note: Assumes the `URL` is already verified to match the expected Superwall deep link format.
  fileprivate var superwallDeepLinkPathComponents: [String] {
    guard let appLinkIndex = pathComponents.firstIndex(of: "app-link") else {
      return []
    }
    return Array(pathComponents[(appLinkIndex + 1)...])
  }

  /// Formats the URL for the deep link event, handling both Universal Link and URL Scheme.
  ///
  /// - Note: Assumes the `URL` is already verified to match the expected Superwall deep link format.
  fileprivate var superwallDeepLinkMappedURL: URL {
    guard let appLinkRange = absoluteString.range(of: "/app-link/") else {
      return self
    }
    let tail = String(absoluteString[appLinkRange.upperBound...])

    let scheme: String
    if let urlScheme = self.scheme,
      urlScheme.lowercased() != "http",
      urlScheme.lowercased() != "https" {
      scheme = urlScheme
    } else if let host = self.host,
      let superwallHostRange = host.range(of: ".superwall") ?? host.range(of: ".superwallapp") {
      scheme = String(host[..<superwallHostRange.lowerBound])
    } else {
      scheme = self.host ?? "superwall"
    }

    let urlString = "\(scheme)://\(tail)"

    return URL(string: urlString) ?? self
  }

  /// Returns the `URL` query params as a `[name: value]` dictionary.
  fileprivate var queryParameters: [String: String] {
    guard
      let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
      let items = components.queryItems
    else {
      return [:]
    }
    var params: [String: String] = [:]
    for item in items {
      if let value = item.value {
        params[item.name] = value
      }
    }
    return params
  }
}
