//
//  SwiftVersion.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 05/08/2025.
//

extension DeviceHelper {
  func currentSwiftVersion() -> String {
  #if swift(>=6.2)
    return "6.2"
  #else
    // A Swift 6 compiler reports this in the Swift 5 language mode.
    return "5.10"
  #endif
  }

  func currentCompilerVersion() -> String {
  #if compiler(>=6.4)
    return "6.4"
  #elseif compiler(>=6.3.3)
    return "6.3.3"
  #elseif compiler(>=6.3.2)
    return "6.3.2"
  #elseif compiler(>=6.3)
    return "6.3"
  #elseif compiler(>=6.2.4)
    return "6.2.4"
  #elseif compiler(>=6.2.3)
    return "6.2.3"
  #elseif compiler(>=6.2)
    return "6.2"
  #else
    return "Unknown"
  #endif
  }
}
