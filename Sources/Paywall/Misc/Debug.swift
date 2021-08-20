//
//  File.swift
//  
//
//  Created by brian on 7/28/21.
//

import Foundation


internal struct Logger {
    
    static func superwallDebug(_ items: Any...) {
        if Paywall.debugMode {
            print("[Superwall]", items)
        }
    }
    
    static func superwallDebug(string: String, error: Swift.Error? = nil) {
        if Paywall.debugMode {
            print("[Superwall] " + string)
            if let e = error {
                print("[Superwall]  →", e)
            }
        }
    }
    
    private static func errorString(error: Swift.Error?) -> String {
        return error == nil ? "" : " - " + (error?.localizedDescription ?? "")
    }
    
}
