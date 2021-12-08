//
//  File.swift
//  
//
//  Created by Jake Mor on 8/27/21.
//

import Foundation
import UIKit

struct DebugResponse {
    var paywallId: Int
    var token: String
    
}

internal class SWDebugManager {
	
	var viewController: SWDebugViewController? = nil

    static let shared = SWDebugManager()
	
	internal var isDebuggerLaunched = false
    
    func handle(deepLink: URL) {
        
        let deepLinkURLString = deepLink.absoluteString
        
        if let launchDebugger = getQueryStringParameter(url: deepLinkURLString, param: "superwall_debug") {
            if launchDebugger == "true" {
                Store.shared.debugKey = getQueryStringParameter(url: deepLinkURLString, param: "token")
                
                if Store.shared.debugKey != nil {
					SWDebugManager.shared.launchDebugger(toPaywall: getQueryStringParameter(url: deepLinkURLString, param: "paywall_id"))
                }
                
            }
        }
        
    }
	
	/// Launches the debugger for you to preview paywalls. If you call `Paywall.track(.deepLinkOpen(deepLinkUrl: url))` from `application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool` in your `AppDelegate`, this funciton is called automatically after scanning your debug QR code in Superwall's web dashboard. Remember to add you URL scheme in settings for QR code scanning to work.
	func launchDebugger(toPaywall paywallId: String? = nil) {
		
		if Paywall.shared.isPaywallPresented {
			Paywall.dismiss { [weak self] in
				self?.launchDebugger(toPaywall: paywallId)
			}
		} else {
			
			if viewController != nil {
				closeDebugger(completion: { [weak self] in
					self?.launchDebugger(toPaywall: paywallId)
				})
			} else {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: { [weak self] in
					self?.presentDebugger(toPaywall: paywallId)
				})
			}
		}
		

		
	}
	
	func presentDebugger(toPaywall paywallId: String? = nil) {
		
//		let presentor = Paywall.shared.presentingWindow?.rootViewController ??
		
		isDebuggerLaunched = true
		if viewController != nil {
			viewController?.paywallId = paywallId
			viewController?.loadPreview()
			UIViewController.topMostViewController?.present(viewController!, animated: true, completion: nil)
		} else {
			viewController = SWDebugViewController()
			viewController?.paywallId = paywallId
			viewController?.modalPresentationStyle = .overFullScreen
			UIViewController.topMostViewController?.present(viewController!, animated: true, completion: nil)
		}
	}
	
	func closeDebugger(completion: (() -> Void)?) {
		
		let animate = completion == nil
		
		if viewController?.presentedViewController != nil {
			viewController?.presentedViewController?.dismiss(animated: animate, completion: { [weak self] in
				self?.viewController?.dismiss(animated: animate, completion: { [weak self] in
					self?.viewController = nil
					self?.isDebuggerLaunched = false
					completion?()
				})
			})
		} else {
			viewController?.dismiss(animated: animate, completion: { [weak self] in
				self?.viewController = nil
				self?.isDebuggerLaunched = false
				completion?()
			})
		}
	
	}
    
    func getQueryStringParameter(url: String, param: String) -> String? {
      guard let url = URLComponents(string: url) else { return nil }
      return url.queryItems?.first(where: { $0.name == param })?.value
    }
    
}
