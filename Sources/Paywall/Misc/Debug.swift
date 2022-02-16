//
//  File.swift
//  
//
//  Created by brian on 7/28/21.
//

import Foundation
import CloudKit


@objc public enum LogLevel: Int, CustomStringConvertible {

	case debug = 10
	case info = 20
	case warn = 30
	case error = 40

	public var description: String {
		switch self {
		case .debug: return "DEBUG"
		case .info: return "INFO"
		case .warn: return "WARN"
		case .error: return "ERROR"
		}
	}
}

public enum LogScope: String {
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
	case all
}

internal struct Logger {
	
	static func shouldPrint(logLevel: LogLevel, scope: LogScope) -> Bool {
		return Paywall.debugMode && logLevel.rawValue >= (Paywall.logLevel?.rawValue ?? 99) && (Paywall.logScopes.contains(scope) || Paywall.logScopes.contains(.all))
	}
	
	static func debug(logLevel: LogLevel, scope: LogScope, message: String? = nil, info: [String: Any]? = nil, error: Swift.Error? = nil) {
		var output = [String]()
		var dumping = [String: Any]()
		
		if let m = message {
			output.append(m)
		}
		
		if let i = info {
			output.append(i.debugDescription)
			dumping["info"] = i
		}
		
		if let e = error {
			output.append(e.localizedDescription)
			dumping["error"] = e
		}

		OnMain {
			Paywall.delegate?.handleLog?(level: logLevel.description, scope: scope.rawValue, message: message, info: info, error: error)
		}
		
		if shouldPrint(logLevel: logLevel, scope: scope) {
			let dateString = Date().isoString.replacingOccurrences(of: "T", with: " ").replacingOccurrences(of: "Z", with: "")
			dump(dumping, name: "[Superwall]  [\(dateString)]  \(logLevel.description)  \(scope.rawValue)  \(message ?? "")", indent: 0, maxDepth: 100, maxItems: 100)
		}
	
	
	}
    
}
