//
//  LocalizationConfig.swift
//  
//
//  Created by Yusuf Tör on 08/03/2022.
//

import Foundation

struct LocalizationConfig: Codable {
  struct LocaleConfig: Codable {
    var locale: String
  }

  var locales: [LocaleConfig]
}

extension LocalizationConfig: Stubbable {
  static func stub() -> LocalizationConfig {
    return LocalizationConfig(
      locales: [LocaleConfig(locale: "en_US")]
    )
  }
}
