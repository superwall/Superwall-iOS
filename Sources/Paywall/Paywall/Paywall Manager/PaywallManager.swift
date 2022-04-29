//
//  File.swift
//
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation
import UIKit

final class PaywallManager {
	static let shared = PaywallManager()
	var presentedViewController: SWPaywallViewController? {
		let vcs = viewControllers.filter {
			$0.isActive
		}
		return vcs.first
	}
  private var viewControllers: Set<SWPaywallViewController> {
    return Set<SWPaywallViewController>(cache.viewControllers)
  }
  private var cache = PaywallCache()

	func removePaywall(withIdentifier identifier: String?) {
    cache.removePaywall(
      withIdentifier: identifier
    )
	}

	func removePaywall(withViewController viewController: SWPaywallViewController) {
    cache.removePaywall(withViewController: viewController)
	}

	func clearCache() {
		cache.clearCache()
	}

	func getPaywallViewController(
    withIdentifier identifier: String?,
    event: EventData?,
    cached: Bool,
    completion: ((Result<SWPaywallViewController, NSError>) -> Void)? = nil
  ) {
    PaywallResponseManager.shared.getResponse(
      identifier: identifier,
      event: event
    ) { [weak self] result in
      guard let self = self else {
        return
      }
      switch result {
      case .success(let response):
        if cached,
          let identifier = response.identifier,
          let viewController = self.cache.getPaywall(withIdentifier: identifier) {
          completion?(.success(viewController))
          return
        }

        let paywallViewController = SWPaywallViewController(
          paywallResponse: response,
          delegate: Paywall.shared
        )

        if let window = UIApplication.shared.keyWindow {
          paywallViewController.view.alpha = 0.01
          window.addSubview(paywallViewController.view)
          paywallViewController.view.transform = CGAffineTransform(
            translationX: UIScreen.main.bounds.width,
            y: 0
          )
          .scaledBy(x: 0.1, y: 0.1)
        }

        self.cache.savePaywall(
          paywallViewController,
          withIdentifier: response.identifier
        )

        completion?(.success(paywallViewController))
      case .failure(let error):
        completion?(.failure(error))
      }
    }
	}
}
