//
//  File.swift
//  
//
//  Created by Jake Mor on 8/27/21.
//

import Foundation

struct DebugResponse {
    var paywallId: Int
    var token: String
    
}

internal class DebugManager {

    static let shared = DebugManager()
    
    func handle(deepLink: URL) {
        
        let deepLinkURLString = deepLink.absoluteString
        
        if let launchDebugger = getQueryStringParameter(url: deepLinkURLString, param: "superwall_debug") {
            if launchDebugger == "true" {
                Store.shared.debugKey = getQueryStringParameter(url: deepLinkURLString, param: "token")
                
                if Store.shared.debugKey != nil {
                    Paywall.launchDebugger(toPaywall: getQueryStringParameter(url: deepLinkURLString, param: "paywall_id"))
                }
                
            }
        }
        
    }
    
    func getQueryStringParameter(url: String, param: String) -> String? {
      guard let url = URLComponents(string: url) else { return nil }
      return url.queryItems?.first(where: { $0.name == param })?.value
    }
    
}
