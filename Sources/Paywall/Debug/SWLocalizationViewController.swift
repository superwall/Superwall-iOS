//
//  SWLanguagePickerViewController.swift
//  
//
//  Created by Jake Mor on 11/13/21.
//

import Foundation
import UIKit

struct LocalizationOption {
	var language: String
	var country: String?
	var locale: String
	
	var sectionTitle: String {
		
		if let f = language.first {
			return String(f).uppercased()
		}
		return "Unknown"
	}
	
	var description: String {
		if let c = country {
			return "\(language) (\(c))"
		}
		
		return language
	}
}

struct LocalizationGrouping {
	var localizations: [LocalizationOption]
	var title: String
}

internal class SWLocalizationViewController: UITableViewController {
	
	var rowModels: [LocalizationGrouping] {
		
		let searchTerm = searchBar.text?.lowercased() ?? ""
		
		if let firstCharacter = searchTerm.first {
			let sections = allRowModels.filter {
				$0.title.contains(String(firstCharacter).uppercased())
			}
			return sections.map {
				LocalizationGrouping(localizations: $0.localizations.filter { $0.description.lowercased().contains(searchTerm) || $0.locale.lowercased().contains(searchTerm) }, title: $0.title)
			}
		}
		
		return allRowModels
		
	}
	
	var allRowModels: [LocalizationGrouping] = {
		let languageIds = NSLocale.availableLocaleIdentifiers
		
		var items = [LocalizationOption]()
		
		for l in languageIds {
		
			let locale = NSLocale.autoupdatingCurrent
			let language = locale.localizedString(forLanguageCode: l)!
		
			let parts = l.split(separator: "_")
		
			var country: String?
		
			if let cc = parts.last, parts.count > 1 {
				country = locale.localizedString(forRegionCode: String(cc)) ?? "Unknown"
			}
			
			items.append(LocalizationOption(language: language, country: country, locale: l))
		
		}
		
		items.sort { a, b in
			return a.description < b.description
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
	
	lazy var searchBar: UISearchBar = {
		
		let searchBar = UISearchBar()
		searchBar.searchBarStyle = UISearchBar.Style.default
		searchBar.placeholder = " Search..."
		searchBar.sizeToFit()
		searchBar.isTranslucent = false
		searchBar.backgroundImage = UIImage()
		searchBar.delegate = self
		return searchBar
		
	}()

	init() {
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Localization"

		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
		tableView.translatesAutoresizingMaskIntoConstraints = false
		tableView.backgroundView = nil
		tableView.backgroundColor = DarkBackgroundColor
		tableView.allowsSelection = true
		tableView.allowsMultipleSelection = false
		
		reloadTableView()
		
		navigationItem.titleView = searchBar
	}
	
	func reloadTableView() {
		tableView.reloadData()
	}
	
}



extension SWLocalizationViewController {
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		dismiss(animated: true, completion: nil)
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return rowModels[section].title
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return rowModels.count
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return rowModels[section].localizations.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
		
		let item = rowModels[indexPath.section].localizations[indexPath.row]
		cell.textLabel?.text = item.description
		cell.textLabel?.textColor = .white
		cell.detailTextLabel?.text = item.locale
		cell.detailTextLabel?.textColor = UIColor.white.withAlphaComponent(0.618)
		cell.backgroundView = nil
		cell.backgroundColor = .clear
		cell.contentView.backgroundColor = .clear
		
		return cell
	}
	
	override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
		return rowModels.map { $0.title }
	}
	
	
}


extension SWLocalizationViewController: UISearchBarDelegate {
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		tableView.reloadData()
	}
}
