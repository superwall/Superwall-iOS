//
//  File.swift
//
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation
import UIKit

internal class PaywallManager {
	static var shared = PaywallManager()

	var cache = [String: SWPaywallViewController]()
	
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

	func viewController(identifier: String?, event: EventData?, cached: Bool, completion: ((SWPaywallViewController?, NSError?) -> Void)? = nil ) {

		let key = cacheKey(for: identifier, event: event)

		if let vc = cache[key], cached {
			completion?(vc, nil)
		} else {
			PaywallResponseManager.shared.getResponse(identifier: identifier, event: event) { r, e in

				if let response = r {
					
					if let identifier = response.identifier, let vc = self.cache[identifier+DeviceHelper.shared.locale], cached {
						completion?(vc, nil)
					} else {
						
						if let vc = SWPaywallViewController(paywallResponse: response, delegate: Paywall.shared) {
						
					
							if let v = UIApplication.shared.keyWindow {
								vc.view.alpha = 0.01
								v.addSubview(vc.view)
								vc.view.transform = CGAffineTransform(translationX: UIScreen.main.bounds.width, y: 0).scaledBy(x: 0.1, y: 0.1)
							}

							self.cache[key] = vc
							
							if let identifier = response.identifier {
								self.cache[identifier+DeviceHelper.shared.locale] = vc
							}
							
							completion?(vc, nil)
							
						} else {
							completion?(nil, NSError(domain: "Failed to create PaywallViewController", code: 104, userInfo: nil))
						}
						
					}

				} else {
					completion?(nil, e)
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
