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
		isDebuggerLaunched = true
		Paywall.dismiss(nil)
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.618) { // helps if from cold launch
			
			if let vc = UIViewController.topMostViewController {
				
				var dvc: SWDebugViewController? = nil
				var isPresented = false
				
				if vc is SWDebugViewController {
					dvc = vc as? SWDebugViewController
					isPresented = true
				} else {
					dvc = SWDebugViewController()
				}
				
				dvc?.paywallId = paywallId
				
				if let dvc = dvc {
					
					if isPresented {
						dvc.loadPreview()
					} else {
						dvc.modalPresentationStyle = .overFullScreen
						vc.present(dvc, animated: true)
					}
				}
				
				
			}
		}
	}
    
    func getQueryStringParameter(url: String, param: String) -> String? {
      guard let url = URLComponents(string: url) else { return nil }
      return url.queryItems?.first(where: { $0.name == param })?.value
    }
    
}
