//
//  File.swift
//
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation
import UIKit

final class PaywallManager {
	static var shared = PaywallManager()

  var cache: [String: SWPaywallViewController] = [:]

	var viewControllers: Set<SWPaywallViewController> {
		return Set<SWPaywallViewController>(Array(cache.values))
	}

	var presentedViewController: SWPaywallViewController? {
		let vcs = viewControllers.filter {
			$0.isActive
		}
		return vcs.first
	}

	func cacheKey(for identifier: String?, event: EventData?) -> String {
		return "\(identifier ?? "$no_id")_\(event?.name ?? "$no_event")_\(DeviceHelper.shared.locale)"
	}

	func removePaywall(identifier: String?, event: EventData?) {
		let key = cacheKey(for: identifier, event: event)
		cache[key] = nil

		if let i = identifier {
			cache[i] = nil
		}
	}

	func removePaywall(viewController: SWPaywallViewController) {
		let keys = cache.allKeys(forValue: viewController)
		keys.forEach { cache[$0] = nil }
	}

	func clearCache() {
		cache.removeAll()
	}

	func viewController(
    identifier: String?,
    event: EventData?,
    cached: Bool,
    completion: ((SWPaywallViewController?, NSError?) -> Void)? = nil
  ) {
		let key = cacheKey(for: identifier, event: event)

		if let viewController = cache[key], cached {
			completion?(viewController, nil)
		} else {
			PaywallResponseManager.shared.getResponse(identifier: identifier, event: event) { response, error in
				if let response = response {
					if let identifier = response.identifier,
            let viewController = self.cache[identifier + DeviceHelper.shared.locale],
            cached {
						completion?(viewController, nil)
					} else {
						if let viewController = SWPaywallViewController(paywallResponse: response, delegate: Paywall.shared) {
							if let window = UIApplication.shared.keyWindow {
								viewController.view.alpha = 0.01
                window.addSubview(viewController.view)
								viewController.view.transform = CGAffineTransform(
                  translationX: UIScreen.main.bounds.width,
                  y: 0
                )
                .scaledBy(x: 0.1, y: 0.1)
							}

							self.cache[key] = viewController

							if let identifier = response.identifier {
								self.cache[identifier + DeviceHelper.shared.locale] = viewController
							}

							completion?(viewController, nil)
						} else {
							completion?(nil, NSError(domain: "Failed to create PaywallViewController", code: 104, userInfo: nil))
						}
					}
				} else {
					completion?(nil, error)
				}
			}
		}
	}
}

extension Dictionary where Value: Equatable {
	func allKeys(forValue val: Value) -> [Key] {
		return self.filter { $1 == val }.map { $0.0 }
	}
}
