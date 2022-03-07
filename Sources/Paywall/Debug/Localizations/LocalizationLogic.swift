//
//  LocalizationLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 07/03/2022.
//

import Foundation

enum LocalizationLogic {
  static func getSortedLocalizations(
    forLocales localeIds: [String]
  ) -> [LocalizationOption] {
    var localizations: [LocalizationOption] = []
    let currentLocale = NSLocale.autoupdatingCurrent

    for localeId in localeIds {
      // Get language
      let localizedLanguage = currentLocale.localizedString(
        forLanguageCode: localeId
      )!
      // swiftlint:disable:previous force_unwrapping

      // Get country
      let locale = NSLocale(localeIdentifier: localeId)
      let localeIdComponents = localeId.split(separator: "_")
      var country: String?

      if let countryCode = locale.countryCode {
        country = currentLocale.localizedString(forRegionCode: countryCode)
      } else if let countryCode = localeIdComponents.last,
        localeIdComponents.count > 1 {
        country = currentLocale.localizedString(forRegionCode: String(countryCode))
      }

      let localizationOption = LocalizationOption(
        language: localizedLanguage,
        country: country,
        locale: localeId
      )
      localizations.append(localizationOption)
    }

    //  let encoder = JSONEncoder()
    //  encoder.outputFormatting = .prettyPrinted
    //
    //  let data = try! encoder.encode(items)
    //  print(String(data: data, encoding: .utf8)!)

    // Sort in ascending manner
    localizations.sort {
      $0.sortDescription < $1.sortDescription
    }
    return localizations
  }

  static func getGroupings(
    for localizationOptions: [LocalizationOption]
  ) -> [LocalizationGrouping] {
    var groupings: [LocalizationGrouping] = []

    for localizationOption in localizationOptions {
      if let currentGrouping = groupings.last {
        if currentGrouping.title != localizationOption.sectionTitle {
          let grouping = LocalizationGrouping(
            localizations: [],
            title: localizationOption.sectionTitle
          )
          groupings.append(grouping)
        }
      } else {
        let grouping = LocalizationGrouping(
          localizations: [],
          title: localizationOption.sectionTitle
        )
        groupings.append(grouping)
      }

      groupings[groupings.count - 1].localizations.append(localizationOption)
    }

    return groupings
  }
}
