//
//  SWLanguagePickerViewController.swift
//  
//
//  Created by Jake Mor on 11/13/21.
//

import Foundation
import UIKit

final class SWLocalizationViewController: UITableViewController {
	var rowModels: [LocalizationGrouping] {
		return LocalizationManager.shared.localizationGroupings(forSearchTerm: searchBar.text)
	}

	var completion: (String) -> Void

	lazy var allRowModels: [LocalizationGrouping] = {
		return LocalizationManager.shared.localizationGroupings
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

	init(completion: @escaping (String) -> Void) {
		self.completion = completion
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
		tableView.backgroundColor = darkBackgroundColor
		tableView.allowsSelection = true
		tableView.allowsMultipleSelection = false

		reloadTableView()

		navigationItem.titleView = searchBar

		tableView.keyboardDismissMode = .onDrag

		navigationController?.navigationBar.tintColor = primaryColor
		view.tintColor = primaryColor
		tableView.sectionIndexColor = primaryColor
	}

	func reloadTableView() {
		tableView.reloadData()
	}
}

extension SWLocalizationViewController {
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		completion(rowModels[indexPath.section].localizations[indexPath.row].locale)
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
		return rowModels.map { $0.title == "Localized" ? "★" : $0.title }
	}
}

extension SWLocalizationViewController: UISearchBarDelegate {
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		tableView.reloadData()
	}
}
