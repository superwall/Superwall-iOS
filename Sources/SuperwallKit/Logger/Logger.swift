//
//  File.swift
//  
//
//  Created by brian on 7/28/21.
//
// swiftlint:disable disable_print

import Foundation

protocol Loggable {
  static func shouldPrint(
    logLevel: LogLevel,
    scope: LogScope
  ) -> Bool

  static func debug(
    logLevel: LogLevel,
    scope: LogScope,
    message: String?,
    info: [String: Any]?,
    error: Swift.Error?
  )
}

extension Loggable {
  static func debug(
    logLevel: LogLevel,
    scope: LogScope,
    message: String? = nil,
    info: [String: Any]? = nil,
    error: Swift.Error? = nil
  ) {
    debug(
      logLevel: logLevel,
      scope: scope,
      message: message,
      info: info,
      error: error
    )
  }
}

enum Logger: Loggable {
	static func shouldPrint(
    logLevel: LogLevel,
    scope: LogScope
  ) -> Bool {
    let logging = Superwall.shared.options.logging
    if logging.level == .none {
      return false
    }
    let exceedsCurrentLogLevel = logLevel.rawValue >= logging.level.rawValue
    let isInScope = logging.scopes.contains(scope)
    let allLogsActive = logging.scopes.contains(.all)

    return exceedsCurrentLogLevel
      && (isInScope || allLogsActive)
	}

	static func debug(
    logLevel: LogLevel,
    scope: LogScope,
    message: String? = nil,
    info: [String: Any]? = nil,
    error: Swift.Error? = nil
  ) {
    Task.detached(priority: .utility) {
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

      await Superwall.shared.dependencyContainer.delegateAdapter.handleLog(
        level: logLevel.description,
        scope: scope.description,
        message: message,
        info: info,
        error: error
      )

      guard shouldPrint(logLevel: logLevel, scope: scope) else {
        return
      }

      var name = "\n\(logLevel.descriptionEmoji) [Superwall] [\(scope.description)] \(logLevel.description)"
      if let message = message {
        name += ": \(message)"
      }
      name += "\n"

      if dumping.isEmpty {
        print(name)
      } else {
        dump(
          dumping,
          name: name,
          indent: 0,
          maxDepth: 100,
          maxItems: 100
        )
      }
    }
	}
}
