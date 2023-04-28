//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/11/2022.
//

import Foundation

/// Specifies the detail of the logs returned from the SDK to the console.
@objc(SWKLogLevel)
public enum LogLevel: Int, CustomStringConvertible, Sendable {
  /// Prints all logs from the SDK to the console. Useful for debugging your app if something isn't working as expected.
  case debug = 10

  /// Prints errors, warnings, and useful information from the SDK to the console.
  case info = 20

  /// Prints errors and warnings from the SDK to the console.
  case warn = 30

  /// Only prints errors from the SDK to the console.
  case error = 40

  /// Turns off all logs.
  case none = 99

  /// The string value of the log level
  public var description: String {
    switch self {
    case .debug: return "DEBUG"
    case .info: return "INFO"
    case .warn: return "WARN"
    case .error: return "ERROR"
    case .none: return "NONE"
    }
  }

  /// The string value of the log level
  public var descriptionEmoji: String {
    switch self {
    case .debug: return "💬"
    case .info: return "ℹ️"
    case .warn: return "⚠️"
    case .error: return "‼️"
    case .none: return ""
    }
  }
}
