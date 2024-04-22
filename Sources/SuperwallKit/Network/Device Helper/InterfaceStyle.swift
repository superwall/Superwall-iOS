//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/04/2024.
//

import Foundation

@objc(SWKInterfaceStyle)
public enum InterfaceStyle: Int, CustomStringConvertible {
  case light
  case dark

  public var description: String {
    switch self {
    case .light:
      return "Light"
    case .dark:
      return "Dark"
    }
  }
}
