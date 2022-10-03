//
//  LocalizationOption.swift
//  Superwall
//
//  Created by Yusuf Tör on 07/03/2022.
//

import Foundation

struct LocalizationOption: Codable {
  var language: String
  var country: String?
  var locale: String
  var description: String
  var isPopular: Bool {
    let isEnglish = locale == "en"
    let isInPopularLocales = LocalizationManager.shared.popularLocales.contains(locale)
    return isInPopularLocales || isEnglish
  }
  var sectionTitle: String {
    if isPopular {
      return "Localized"
    }

    if let language = language.first {
      return String(language).uppercased()
    }
    return "Unknown"
  }
  var sortDescription: String {
    return "\(isPopular ? "a" : "b") \(description)"
  }

  init(
    language: String,
    country: String?,
    locale: String
  ) {
    self.language = language
    self.country = country
    self.locale = locale

    if let country = country {
      self.description = "\(language) (\(country))"
    } else {
      self.description = language
    }
  }

  func included(forSearchTerm query: String) -> Bool {
    let isInDescription = description.lowercased().contains(query)
    let isInLocale = locale.lowercased().contains(query)
    return isInDescription || isInLocale
  }
}
