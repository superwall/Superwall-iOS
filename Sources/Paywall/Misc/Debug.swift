//
//  File.swift
//  
//
//  Created by brian on 7/28/21.
//

import Foundation


public enum LogLevel: Int, CustomStringConvertible {

	case debug, info, warn, error

	public var description: String {
		switch self {
		case .debug: return "DEBUG"
		case .info: return "INFO"
		case .warn: return "WARN"
		case .error: return "ERROR"
		}
	}

}

internal enum LogScope: String {
	case localizationManager
	case bounceButton
	case debugManager
	case debugViewController
	case localizationViewController
	case gameControllerManager
	case device
	case network
	case paywallEvents
	case paywallResponseManager
	case productsManager
	case storeKitManager
	case events
	case paywallCore
	case paywallPresentation
	case paywallTransactions
	case paywallViewController
	case cache
}

internal struct Logger {
    
//    static func superwallDebug(_ items: Any...) {
//        if Paywall.debugMode {
//            print("[Superwall]", items)
//        }
//    }
	
	static func debug(logLevel: LogLevel, scope: LogScope, message: String? = nil, info: [String: Any]? = nil, error: Swift.Error? = nil) {
		if Paywall.debugMode {
			
			var output = [String]()
			
			if let m = message {
				output.append(m)
			}
			
			if let i = info {
				output.append(i.debugDescription)
			}
			
			if let e = error {
				output.append(e.localizedDescription)
			}
			
			print("[Superwall]\t\(logLevel.description)\t\(scope.rawValue)\t\(output.joined(separator: "\t"))")
			
		
		}
	}
    
//    static func superwallDebug(string: String, error: Swift.Error? = nil) {
//        if Paywall.debugMode {
//            print("[Superwall] " + string)
//            if let e = error {
//                print("[Superwall] Error →", e)
//            }
//        }
//    }
//
//    private static func errorString(error: Swift.Error?) -> String {
//        return error == nil ? "" : " - " + (error?.localizedDescription ?? "")
//    }
    
}
