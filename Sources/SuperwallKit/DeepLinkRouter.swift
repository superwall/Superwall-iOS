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
          pathComponents: deepLinkUrl.superwallDeepLinkPathComponents,
          queryParameters: deepLinkUrl.queryParameters
        )
      }
    } else {
      deepLinkUrl = url
    }
    
    Task {
      await Superwall.shared.track(InternalSuperwallEvent.DeepLink(url: url))
    }
    return debugManager.handle(deepLinkUrl: url)
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
    if url.redeemableCode != nil || DebugManager.outcomeForDeepLink(url: url) != nil {
      pendingDeepLink = url
      return true
    }
    return false
  }
}

extension URL {
  fileprivate var redeemableCode: String? {
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
  
  /// Returns true if the URL matches the expected Superwall Deep Link format.
  var isSuperwallDeepLink: Bool {
    guard let host = self.host,
          host.hasSuffix(".superwall.app") || host.hasSuffix(".superwallapp.dev") else {
      return false
    }
    return self.path.hasPrefix("/app-link/")
  }
  
  /// Assumes the URL is already verified to match the expected Superwall Deep Link format.
  fileprivate var superwallDeepLinkPathComponents: [String] {
    let components = self.pathComponents
    guard let appLinkIndex = components.firstIndex(of: "app-link") else {
      return []
    }
    return Array(components[(appLinkIndex + 1)...])
  }
  
  /// Assumes the URL is already verified to match the expected Superwall Deep Link format.
  /// returns the equivalent URL formatted for the deep link event, handling both Universal Link and URL Scheme
  fileprivate var superwallDeepLinkMappedURL: URL {
    let absoluteString: String = self.absoluteString
    
    guard let markerRange = absoluteString.range(of: "/app-link/") else {
      return self
    }
    let tail: String = String(absoluteString[markerRange.upperBound...])
    
    let scheme: String
    if let urlScheme = self.scheme,
       urlScheme.lowercased() != "http",
       urlScheme.lowercased() != "https" {
      scheme = urlScheme
    } else if let host = self.host,
              let cut = host.range(of: ".superwall") ?? host.range(of: ".superwallapp") {
      scheme = String(host[..<cut.lowerBound])
    } else {
      scheme = self.host ?? "superwall"
    }
    
    let urlString: String = "\(scheme)://\(tail)"
    
    return URL(string: urlString) ?? self
  }
  
  
  fileprivate var queryParameters: [String: String] {
    guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
          let items = components.queryItems else {
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
