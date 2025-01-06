//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 06/01/2025.
//

import Foundation

func convertJSONToDictionary(attribution: [String: JSON]) -> [String: Any] {
  var dictionary: [String: Any] = [:]

  for (key, jsonValue) in attribution {
    dictionary[key] = jsonValue.rawValue
  }

  return dictionary
}
