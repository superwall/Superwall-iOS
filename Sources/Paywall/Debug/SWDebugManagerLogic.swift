//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/04/2022.
//

import Foundation

enum SWDebugManagerLogic {
  enum Parameter: String {
    case token
    case paywallId = "paywall_id"
    case superwallDebug = "superwall_debug"
  }

  static func getQueryItemValue(
    fromUrl url: URL,
    withName name: Parameter
  ) -> String? {
    guard let url = URLComponents(string: url.absoluteString) else {
      return nil
    }
    guard let queryItems = url.queryItems else {
      return nil
    }
    guard let item = queryItems.first(where: { $0.name == name.rawValue }) else {
      return nil
    }
    return item.value
  }
}
