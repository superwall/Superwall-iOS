//
//  File.swift
//  
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation

final class LocalizationManager {
	let popularLocales = ["de_DE", "es_US"]
	let localizationGroupings: [LocalizationGrouping]

  init() {
    let localeIds = Locale.availableIdentifiers
    let sortedLocalizations = LocalizationLogic.getSortedLocalizations(
      forLocales: localeIds,
      popularLocales: popularLocales
    )
    let localizationGroupings = LocalizationLogic.getGroupings(for: sortedLocalizations)
    self.localizationGroupings = localizationGroupings
  }

	func localizationGroupings(forSearchTerm searchTerm: String?) -> [LocalizationGrouping] {
		let query = searchTerm?.lowercased() ?? ""

    if query.isEmpty {
      return localizationGroupings
    }

    let output: [LocalizationGrouping] = localizationGroupings.map { grouping in
      let filteredLocalizations = grouping.localizations.filter { localization in
        localization.included(forSearchTerm: query)
      }
      return LocalizationGrouping(
        localizations: filteredLocalizations,
        title: grouping.title
      )
    }

    return output.filter { !$0.localizations.isEmpty }
	}
}
