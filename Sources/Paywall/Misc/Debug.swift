//
//  File.swift
//  
//
//  Created by brian on 7/28/21.
//

import Foundation
import CloudKit

/// Specifies the detail of the logs returned from the SDK to the console.
@objc public enum LogLevel: Int, CustomStringConvertible {
  /// Prints all logs from the SDK to the console. Useful for debugging your app if something isn't working as expected.
  case debug = 10
  /// Prints errors, warnings, and useful information from the SDK to the console.
	case info = 20
  /// Prints errors and warnings from the SDK to the console.
	case warn = 30
  /// Only prints errors from the SDK to the console.
	case error = 40

  /// The string value of the log level
	public var description: String {
		switch self {
		case .debug: return "DEBUG"
		case .info: return "INFO"
		case .warn: return "WARN"
		case .error: return "ERROR"
		}
	}
}

/// The possible scope of logs to print to the console.
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

enum Logger {
	static func shouldPrint(
    logLevel: LogLevel,
    scope: LogScope
  ) -> Bool {
    let exceedsCurrentLogLevel = logLevel.rawValue >= (Paywall.logLevel?.rawValue ?? 99)
    let isInScope = Paywall.logScopes.contains(scope)
    let allLogsActive = Paywall.logScopes.contains(.all)

    return Paywall.debugMode
      && exceedsCurrentLogLevel
      && (isInScope || allLogsActive)
	}

	static func debug(
    logLevel: LogLevel,
    scope: LogScope,
    message: String? = nil,
    info: [String: Any]? = nil,
    error: Swift.Error? = nil
  ) {
    var output: [String] = []
    var dumping: [String: Any] = [:]

    if let message = message {
			output.append(message)
		}

		if let info = info {
			output.append(info.debugDescription)
			dumping["info"] = info
		}

		if let error = error {
			output.append(error.localizedDescription)
			dumping["error"] = error
		}

		onMain {
			Paywall.delegate?.handleLog?(
        level: logLevel.description,
        scope: scope.rawValue,
        message: message,
        info: info,
        error: error
      )
		}

		if shouldPrint(logLevel: logLevel, scope: scope) {
			let dateString = Date().isoString
        .replacingOccurrences(of: "T", with: " ")
        .replacingOccurrences(of: "Z", with: "")

			dump(
        dumping,
        name: "[Superwall]  [\(dateString)]  \(logLevel.description)  \(scope.rawValue)  \(message ?? "")",
        indent: 0,
        maxDepth: 100,
        maxItems: 100
      )
		}
	}
}
