//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import Foundation

import UIKit
@testable import SuperwallKit

final class LoggerMock: Loggable {
  static var shouldPrintCalled = false
  static var debugCalled = false

  static func shouldPrint(logLevel: SuperwallKit.LogLevel, scope: SuperwallKit.LogScope) -> Bool {
    shouldPrintCalled = true
    return true
  }

  static func debug(logLevel: SuperwallKit.LogLevel, scope: SuperwallKit.LogScope, message: String?, info: [String : Any]?, error: Error?) {
    debugCalled = true
  }
}
