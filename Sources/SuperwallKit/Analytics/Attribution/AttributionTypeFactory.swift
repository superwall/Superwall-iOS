//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/08/2025.
//

import Foundation

enum AttributionTypeFactory {
  static func asIdProxy() -> ASIdManagerProxy? {
    return ASIdManagerProxy.identifierClass == nil ? nil : ASIdManagerProxy()
  }
}
