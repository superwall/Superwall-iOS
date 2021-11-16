//
//  File.swift
//  
//
//  Created by Jake Mor on 11/15/21.
//

import Foundation

struct LocalizationOption: Codable {
	var language: String
	var country: String?
	var locale: String
	var description: String
	
	var isPopular: Bool {
		return LocalizationManager.shared.popularLocales.contains(locale) || locale == "en"
	}
	
	
	var sectionTitle: String {
		
		if isPopular {
			return "Localized"
		}
		
		if let f = language.first {
			return String(f).uppercased()
		}
		return "Unknown"
	}
	
	var sortDescription: String {
		return "\(isPopular ? "a" : "b") \(description)"
	}
	
	
	func included(forSearchTerm query: String) -> Bool {
		return description.lowercased().contains(query) || locale.lowercased().contains(query)
	}
	
	init(language: String, country: String?, locale: String) {
		self.language = language
		self.country = country
		self.locale = locale

		if let c = country {
			self.description = "\(language) (\(c))"
		} else {
			self.description = language
		}
		
	}
}

struct LocalizationGrouping {
	var localizations: [LocalizationOption]
	var title: String
}

internal class LocalizationManager {

	static let shared = LocalizationManager()
	
	var popularLocales = ["de_DE", "es_US"]
	
	var selectedLocale: String? = nil
		
	lazy var localizationGroupings: [LocalizationGrouping] = {
		let languageIds = NSLocale.availableLocaleIdentifiers
		
		var items = [LocalizationOption]()
		
		for l in languageIds {
		
			let locale = NSLocale.autoupdatingCurrent
			let language = locale.localizedString(forLanguageCode: l)!
			
			let locale2 = NSLocale(localeIdentifier: l)
		
			let parts = l.split(separator: "_")
		
			var country: String?
			
			if let cc = locale2.countryCode {
				country = locale.localizedString(forRegionCode: cc)
			}
		
			if let cc = parts.last, parts.count > 1, country == nil {
				country = locale.localizedString(forRegionCode: String(cc))
			}
			
			items.append(LocalizationOption(language: language, country: country, locale: l))
		
		}
		
//		let encoder = JSONEncoder()
//		encoder.outputFormatting = .prettyPrinted
//
//		let data = try! encoder.encode(items)
//		print(String(data: data, encoding: .utf8)!)
		
		items.sort { a, b in
			return a.sortDescription < b.sortDescription
		}
		
		var groupings = [LocalizationGrouping]()
		
		for i in items {

			if let currentGrouping = groupings.last {
				if currentGrouping.title != i.sectionTitle {
					groupings.append(LocalizationGrouping(localizations: [], title: i.sectionTitle))
				}
			} else {
				groupings.append(LocalizationGrouping(localizations: [], title: i.sectionTitle))
			}
			
			groupings[groupings.count - 1].localizations.append(i)
			
		}
		
		return groupings
	}()
	
	
	func localizationGroupings(forSearchTerm searchTerm: String?) -> [LocalizationGrouping] {
		
		let query = searchTerm?.lowercased() ?? ""
		
		if !query.isEmpty {
			let output = localizationGroupings.map {
				LocalizationGrouping(localizations: $0.localizations.filter { $0.included(forSearchTerm: query) }, title: $0.title)
			}
			
			return output.filter {
				$0.localizations.count > 0
			}
		}
		
		return localizationGroupings
	}
	
	func printLocales() {
		
	}
}
	
