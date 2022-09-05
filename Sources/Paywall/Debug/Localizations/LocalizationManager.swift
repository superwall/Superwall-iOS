//
//  File.swift
//  
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation

final class LocalizationManager {
	static let shared = LocalizationManager()
	var popularLocales = ["de_DE", "es_US"]
	var selectedLocale: String?

	lazy var localizationGroupings: [LocalizationGrouping] = {
		let localeIds = Locale.availableIdentifiers
    let sortedLocalizations = LocalizationLogic.getSortedLocalizations(forLocales: localeIds)
    let groupings = LocalizationLogic.getGroupings(for: sortedLocalizations)

    return groupings
	}()

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
