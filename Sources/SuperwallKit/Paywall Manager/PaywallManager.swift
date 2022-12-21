//
//  File.swift
//
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation
import UIKit

class PaywallManager {
  @MainActor
  var presentedViewController: PaywallViewController? {
    return PaywallViewController.cache.first { $0.isActive }
	}

  @MainActor
  private let cache: PaywallCache

  private let deviceHelper: DeviceHelper
  private let sessionEventsManager: SessionEventsManager
  private let storage: Storage
  private let paywallManager: PaywallManager

  init(
    deviceHelper: DeviceHelper,
    sessionEventsManager: SessionEventsManager,
    storage: Storage,
    paywallManager: PaywallManager
  ) {
    self.deviceHelper = deviceHelper
    self.sessionEventsManager = sessionEventsManager
    self.storage = storage
    self.paywallManager = paywallManager
    self.cache = PaywallCache(deviceLocaleString: deviceHelper.locale)
  }

  @MainActor
	func removePaywall(withIdentifier identifier: String?) {
    cache.removePaywall(
      withIdentifier: identifier
    )
	}

  @MainActor
	func removePaywallViewController(_ viewController: PaywallViewController) {
    cache.removePaywall(withViewController: viewController)
	}

  @MainActor
	func resetCache() {
		cache.clearCache()
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
    cached: Bool
  ) async throws -> PaywallViewController {
    let paywall = try await PaywallRequestManager.shared.getPaywall(from: request)

    if cached,
      let viewController = self.cache.getPaywallViewController(withIdentifier: paywall.identifier) {
      // Set product-related vars again incase products have been substituted into paywall.
      viewController.paywall.products = paywall.products
      viewController.paywall.productIds = paywall.productIds
      viewController.paywall.productVariables = paywall.productVariables
      viewController.paywall.productsLoadingInfo = paywall.productsLoadingInfo

      // Set free trial again as this needs to be refreshed every time.
      viewController.paywall.isFreeTrialAvailable = paywall.isFreeTrialAvailable
      return viewController
    }

    let paywallViewController = PaywallViewController(
      paywall: paywall,
      delegate: Superwall.shared,
      deviceHelper: deviceHelper,
      sessionEventsManager: sessionEventsManager,
      storage: storage,
      paywallManager: paywallManager
    )

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
