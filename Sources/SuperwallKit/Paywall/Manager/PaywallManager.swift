//
//  File.swift
//
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

class PaywallManager {
  #if canImport(WebKit)
  /// Every factory the paywall view controllers need.
  typealias Factory = ViewControllerFactory
    & CacheFactory
    & DeviceHelperFactory
    & PaywallArchiveManagerFactory

  var presentedViewController: PaywallViewController? {
    return cache.activePaywallViewController
  }
  #else
  /// watchOS and tvOS make no paywall view controllers, so only the factories
  /// for fetching paywalls are needed.
  typealias Factory = DeviceHelperFactory
    & PaywallArchiveManagerFactory
  #endif
  private let queue = DispatchQueue(label: "com.superwall.paywallmanager")
  private unowned let paywallRequestManager: PaywallRequestManager
  private unowned let factory: Factory

  #if canImport(WebKit)
  var cache: PaywallViewControllerCache {
    return queue.sync { _cache ?? createCache() }
  }
  private var _cache: PaywallViewControllerCache?
  #endif

  private var paywallArchiveManager: PaywallArchiveManager {
    return queue.sync { _paywallArchiveManager ?? createPaywallArchiveManager() }
  }
  private var _paywallArchiveManager: PaywallArchiveManager?

  init(
    factory: Factory,
    paywallRequestManager: PaywallRequestManager
  ) {
    self.factory = factory
    self.paywallRequestManager = paywallRequestManager
  }

  #if canImport(WebKit)
  private func createCache() -> PaywallViewControllerCache {
    let cache = factory.makeCache()
    _cache = cache
    return cache
  }
  #endif

  private func createPaywallArchiveManager() -> PaywallArchiveManager {
    let paywallArchiveManager = factory.makePaywallArchiveManager()
    _paywallArchiveManager = paywallArchiveManager
    return paywallArchiveManager
  }

  #if canImport(WebKit)
	func resetCache() {
		cache.removeAll()
	}
  #endif

  /// Removes cached `Paywall` and `PaywallViewController` objects so that
  /// they can be fetched again when the config refreshes.
  func removePaywalls(withIds ids: Set<String>) async {
    await paywallRequestManager.removePaywalls(withIds: ids)

    #if canImport(WebKit)
    let deviceInfo = factory.makeDeviceInfo()

    for id in ids {
      let cacheKey = PaywallCacheLogic.key(
        identifier: id,
        locale: deviceInfo.locale
      )
      cache.removePaywallViewController(forKey: cacheKey)
    }
    #endif
  }

  func getPaywall(from request: PaywallRequest) async throws -> Paywall {
    return try await paywallRequestManager.getPaywall(from: request)
  }

  /// Tries to preload the archive for the paywall, if available.
  ///
  /// - Parameter paywall: The paywall whose archive to preload.
  func attemptToPreloadArchive(from paywall: Paywall) async {
    await paywallArchiveManager.preloadArchive(paywall: paywall)
  }

  #if canImport(WebKit)
  /// Gets the paywall view controller for a given paywall.
  @MainActor
  func getViewController(
    for paywall: Paywall,
    isDebuggerLaunched: Bool,
    isForPresentation: Bool,
    delegate: PaywallViewControllerDelegateAdapter?
  ) async throws -> PaywallViewController {
    let deviceInfo = factory.makeDeviceInfo()
    let cacheKey = PaywallCacheLogic.key(
      identifier: paywall.identifier,
      locale: deviceInfo.locale
    )

    if !isDebuggerLaunched,
      let viewController = self.cache.getPaywallViewController(forKey: cacheKey) {
      // There is one view controller per paywall. While it's on screen it
      // belongs to that presentation, so leave it alone. The experiment,
      // products and delegate for a request are applied when the request
      // claims the view controller, in `set(request:paywall:...)`.
      if viewController.isActive {
        return viewController
      }

      let outcomes = PaywallManagerLogic.handleCachedPaywall(
        newPaywall: paywall,
        oldPaywall: viewController.paywall,
        isForPresentation: isForPresentation
      )

      for outcome in outcomes {
        switch outcome {
        case .loadWebView:
          viewController.loadWebView()
        case .replacePaywall:
          viewController.paywall = paywall
        }
      }

      return viewController
    }

    let paywallViewController = factory.makePaywallViewController(
      for: paywall,
      withCache: cache,
      withPaywallArchiveManager: paywallArchiveManager,
      delegate: delegate
    )
    cache.save(paywallViewController, forKey: cacheKey)

    if isForPresentation {
      // Only preload if it's actually gonna present the view.
      // Not if we're just checking it's result
      #if os(macOS)
      // Reading `view` loads it. `loadViewIfNeeded()` needs macOS 14.
      _ = paywallViewController.view
      #else
      paywallViewController.loadViewIfNeeded()
      #endif
    }

    return paywallViewController
  }
  #endif
}
