//
//  File.swift
//
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation
import UIKit

/*
 Get paywall by key and by which one is active.
 */
class PaywallManager {
  var presentedViewController: PaywallViewController? {
    return cache.getActivePaywallViewController()
	}
  private unowned let paywallRequestManager: PaywallRequestManager
  private unowned let factory: ViewControllerFactory & CacheFactory & DeviceInfoFactory

  private lazy var cache: PaywallViewControllerCache = factory.makeCache()

  init(
    factory: ViewControllerFactory & CacheFactory & DeviceInfoFactory,
    paywallRequestManager: PaywallRequestManager
  ) {
    self.factory = factory
    self.paywallRequestManager = paywallRequestManager
  }

  func setActivePaywallVcKey(to key: String) {
    cache.activePaywallVcKey = key
  }

	func removePaywallViewController(forKey: String) {
    cache.removePaywallViewController(forKey: forKey)
	}

	func resetCache() {
		cache.removeAll()
	}

  /// First, this gets the paywall response for a specified paywall identifier or trigger event.
  /// It then creates the paywall view controller from that response, and caches it.
  ///
  /// If no `identifier` or `event` is specified, this gets the default paywall for the user.
  ///
  /// - Parameters:
  ///   - presentationInfo: Info concerning the cause of the paywall presentation and data associated with it.
  ///   - cached: Whether or not the paywall is cached.
  ///   - completion: A completion block called with the resulting paywall view controller.
  @MainActor
  func getPaywallViewController(
    from request: PaywallRequest,
    isPreloading: Bool,
    isDebuggerLaunched: Bool
  ) async throws -> PaywallViewController {
    let paywall = try await paywallRequestManager.getPaywall(from: request)
    let deviceInfo = factory.makeDeviceInfo()
    let cacheKey = PaywallCacheLogic.key(
      identifier: paywall.identifier,
      locale: deviceInfo.locale
    )

    if !isDebuggerLaunched,
      let viewController = self.cache.getPaywallViewController(forKey: cacheKey) {

      if !isPreloading {
        viewController.paywall.overrideProductsIfNeeded(from: paywall)
      }
      return viewController
    }

    let paywallViewController = factory.makePaywallViewController(
      for: paywall,
      withCache: cache
    )
    cache.save(paywallViewController, forKey: cacheKey)

    if let window = UIApplication.shared.activeWindow {
      paywallViewController.view.alpha = 0.01
      window.addSubview(paywallViewController.view)
      paywallViewController.view.transform = CGAffineTransform(
        translationX: UIScreen.main.bounds.width,
        y: 0
      )
      .scaledBy(x: 0.1, y: 0.1)
    }

    return paywallViewController
  }
}
