//
//  DebugPaywallPickerViewController.swift
//  SuperwallKit
//
//  The debugger's paywall list: a searchable, sectioned table of the local
//  surfaces a `superwall dev` server serves and the app's published paywalls.
//

import UIKit

@MainActor
final class DebugPaywallPickerViewController: UIViewController {
  private let localSurfaceIds: [String]
  private let publishedNames: [String]
  private let selectedLocalId: String?
  private let selectedPublishedIndex: Int?
  private let onSelect: (DebugPickerLogic.Kind) -> Void

  private var sections: [DebugPickerLogic.Section] = []

  private lazy var tableView: UITableView = {
    let table = UITableView(frame: .zero, style: .insetGrouped)
    table.backgroundColor = darkBackgroundColor
    table.separatorColor = UIColor.white.withAlphaComponent(0.1)
    table.dataSource = self
    table.delegate = self
    table.keyboardDismissMode = .onDrag
    table.translatesAutoresizingMaskIntoConstraints = false
    return table
  }()

  private lazy var searchController: UISearchController = {
    let controller = UISearchController(searchResultsController: nil)
    controller.searchResultsUpdater = self
    controller.obscuresBackgroundDuringPresentation = false
    controller.searchBar.placeholder = "Search paywalls"
    controller.searchBar.tintColor = primaryColor
    controller.searchBar.searchTextField.textColor = .white
    return controller
  }()

  init(
    localSurfaceIds: [String],
    publishedNames: [String],
    selectedLocalId: String?,
    selectedPublishedIndex: Int?,
    onSelect: @escaping (DebugPickerLogic.Kind) -> Void
  ) {
    self.localSurfaceIds = localSurfaceIds
    self.publishedNames = publishedNames
    self.selectedLocalId = selectedLocalId
    self.selectedPublishedIndex = selectedPublishedIndex
    self.onSelect = onSelect
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = darkBackgroundColor
    title = "Paywalls"

    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(pressedClose)
    )
    navigationItem.rightBarButtonItem?.tintColor = primaryColor

    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    reload(query: "")
  }

  private func reload(query: String) {
    sections = DebugPickerLogic.sections(
      localSurfaceIds: localSurfaceIds,
      publishedNames: publishedNames,
      selectedLocalId: selectedLocalId,
      selectedPublishedIndex: selectedPublishedIndex,
      query: query
    )
    tableView.reloadData()
  }

  @objc private func pressedClose() {
    dismiss(animated: true)
  }
}

// MARK: - Table

extension DebugPaywallPickerViewController: UITableViewDataSource, UITableViewDelegate {
  func numberOfSections(in tableView: UITableView) -> Int {
    return sections.count
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sections[section].rows.count
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return sections[section].title
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = sections[indexPath.section].rows[indexPath.row]
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.backgroundColor = lightBackgroundColor
    cell.textLabel?.text = row.title
    cell.textLabel?.textColor = .white
    cell.textLabel?.font = .systemFont(ofSize: 16, weight: row.isSelected ? .semibold : .regular)
    cell.accessoryType = row.isSelected ? .checkmark : .none
    cell.tintColor = primaryColor
    let selected = UIView()
    selected.backgroundColor = UIColor.white.withAlphaComponent(0.08)
    cell.selectedBackgroundView = selected
    return cell
  }

  func tableView(
    _ tableView: UITableView,
    willDisplayHeaderView view: UIView,
    forSection section: Int
  ) {
    guard let header = view as? UITableViewHeaderFooterView else {
      return
    }
    // A grouped header renders through its content configuration on iOS 14+,
    // which ignores `textLabel` — the default grey is unreadable on the
    // debugger's near-black sheet.
    if #available(iOS 14.0, *) {
      var configuration = header.defaultContentConfiguration()
      configuration.text = sections[section].title
      configuration.textProperties.color = UIColor.white.withAlphaComponent(0.5)
      configuration.textProperties.font = .systemFont(ofSize: 13, weight: .semibold)
      header.contentConfiguration = configuration
    } else {
      header.textLabel?.textColor = UIColor.white.withAlphaComponent(0.5)
      header.textLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
    }
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let row = sections[indexPath.section].rows[indexPath.row]
    let onSelect = self.onSelect
    dismiss(animated: true) {
      onSelect(row.kind)
    }
  }
}

// MARK: - Search

extension DebugPaywallPickerViewController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    reload(query: searchController.searchBar.text ?? "")
  }
}
