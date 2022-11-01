//
//  LocalizationConfig.swift
//  
//
//  Created by Yusuf Tör on 08/03/2022.
//

import Foundation

struct LocalizationConfig: Decodable {
  struct LocaleConfig: Decodable {
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
