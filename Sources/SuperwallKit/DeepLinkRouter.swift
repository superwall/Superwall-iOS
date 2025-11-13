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
    // Check if the URL matches the expected web2app format
    if let code = url.redeemableCode {
      Task {
        await webEntitlementRedeemer.redeem(.code(code))
      }
      return true
    }

    let deepLinkUrl: URL
    if url.isSuperwallDeepLink {
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


    Task {
      await Superwall.shared.track(InternalSuperwallEvent.DeepLink(url: deepLinkUrl))
    }
    return debugManager.handle(deepLinkUrl: deepLinkUrl)
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
  static func storeDeepLink(_ url: URL) -> Bool {
    pendingDeepLink = url
    return true
  }
}

extension URL {
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
