//
//  TestModeModalViewController.swift
//  Superwall
//
//  Created by Claude on 2026-02-05.
//

#if !os(macOS)
import UIKit

/// The main modal view controller for the test mode modal.
final class TestModeModalViewController: UIViewController {
  static let freeTrialCellId = "FreeTrialCell"

  let reason: TestModeReason
  let userId: String
  let isIdentified: Bool
  let hasPurchaseController: Bool
  private let availableEntitlements: [String]
  private let initialFreeTrialOverride: FreeTrialOverride
  let apiKey: String
  let networkEnvironment: SuperwallOptions.NetworkEnvironment

  var onDismiss: ((Set<Entitlement>, FreeTrialOverride) -> Void)?
  var selectedFreeTrialOverride: FreeTrialOverride
  private var selectedEntitlements: [String: EntitlementSelection] = [:]
  private var entitlementRowViews: [EntitlementRowView] = []

  var rows: [TestModeInfoRow] = []

  private lazy var scrollView: UIScrollView = {
    let scroll = UIScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.showsVerticalScrollIndicator = true
    return scroll
  }()

  private lazy var contentStackView: UIStackView = {
    let stack = UIStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.spacing = 16
    stack.alignment = .fill
    return stack
  }()

  private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "\u{1F9EA} Test Mode Active"
    label.textColor = .white
    label.font = .boldSystemFont(ofSize: 20)
    label.textAlignment = .center
    return label
  }()

  private lazy var reasonLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "\(reason.description).\nAll purchases will be simulated and " +
      "product data will be retrieved from the Superwall dashboard."
    label.textColor = UIColor.white.withAlphaComponent(0.7)
    label.font = .systemFont(ofSize: 14)
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()

  private lazy var tableView: UITableView = {
    let table = UITableView(frame: .zero, style: .plain)
    table.translatesAutoresizingMaskIntoConstraints = false
    table.backgroundColor = .clear
    table.separatorColor = UIColor.white.withAlphaComponent(0.1)
    table.dataSource = self
    table.delegate = self
    table.register(TestModeInfoCell.self, forCellReuseIdentifier: TestModeInfoCell.reuseId)
    table.register(UITableViewCell.self, forCellReuseIdentifier: Self.freeTrialCellId)
    table.isScrollEnabled = false
    table.rowHeight = UITableView.automaticDimension
    table.estimatedRowHeight = 60
    table.sectionHeaderHeight = 0
    table.sectionFooterHeight = 0
    return table
  }()

  private lazy var entitlementsSectionLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Starting Entitlements"
    label.textColor = primaryColor
    label.font = .boldSystemFont(ofSize: 13)
    return label
  }()

  private lazy var entitlementsDescriptionLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Select the state of existing entitlements:"
    label.textColor = .white
    label.font = .systemFont(ofSize: 14)
    label.numberOfLines = 0
    return label
  }()

  private lazy var entitlementsStackView: UIStackView = {
    let stack = UIStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.spacing = 8
    return stack
  }()

  private lazy var resetButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Reset to Defaults", for: .normal)
    button.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 14)
    button.addTarget(self, action: #selector(resetToDefaults), for: .touchUpInside)
    return button
  }()

  private lazy var okButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("OK", for: .normal)
    button.setTitleColor(.white, for: .normal)
    button.titleLabel?.font = .boldSystemFont(ofSize: 16)
    button.backgroundColor = primaryButtonBackgroundColor
    button.layer.cornerRadius = 24
    button.addTarget(self, action: #selector(dismissModal), for: .touchUpInside)
    return button
  }()

  private var tableViewHeightConstraint: NSLayoutConstraint?

  init(
    reason: TestModeReason,
    userId: String,
    isIdentified: Bool,
    hasPurchaseController: Bool,
    availableEntitlements: [String],
    initialFreeTrialOverride: FreeTrialOverride,
    apiKey: String,
    networkEnvironment: SuperwallOptions.NetworkEnvironment
  ) {
    self.reason = reason
    self.userId = userId
    self.isIdentified = isIdentified
    self.hasPurchaseController = hasPurchaseController
    self.availableEntitlements = availableEntitlements
    self.initialFreeTrialOverride = initialFreeTrialOverride
    self.apiKey = apiKey
    self.networkEnvironment = networkEnvironment

    // Load saved override or use initial
    self.selectedFreeTrialOverride = TestModeSettingsStore.loadFreeTrialOverride(
      fallback: initialFreeTrialOverride
    )

    super.init(nibName: nil, bundle: nil)

    // Loaded up front so the saved choices can be handed back even if the
    // sheet never gets shown.
    let savedSettings = loadSavedSettings()
    for entitlementId in availableEntitlements {
      if let selection = savedSettings[entitlementId], selection.state != nil {
        selectedEntitlements[entitlementId] = selection
      }
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = darkBackgroundColor
    isModalInPresentation = true
    buildRows()
    layoutUI()
    setupEntitlementRows()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateTableViewHeight()
  }

  @objc private func dismissModal() {
    saveSettings()
    dismiss(animated: true) { [weak self] in self?.finish() }
  }

  @objc private func resetToDefaults() {
    selectedEntitlements.removeAll()
    for rowView in entitlementRowViews {
      rowView.reset()
    }
    selectedFreeTrialOverride = .useDefault
    reloadFreeTrialSection()
    clearSavedSettings()
  }

  func reloadFreeTrialSection() {
    // Reload just the free trial row (last row in the table)
    let freeTrialIndex = IndexPath(row: rows.count, section: 0)
    tableView.reloadRows(at: [freeTrialIndex], with: .none)
  }
}

// MARK: - Persistence

extension TestModeModalViewController {
  func saveSettings() {
    TestModeSettingsStore.save(selectedEntitlements, freeTrialOverride: selectedFreeTrialOverride)
  }

  func loadSavedSettings() -> [String: EntitlementSelection] {
    return TestModeSettingsStore.loadSelections()
  }

  func clearSavedSettings() {
    TestModeSettingsStore.clear()
  }

  func buildEntitlements() -> Set<Entitlement> {
    return TestModeSettingsStore.entitlements(from: selectedEntitlements)
  }
}

// MARK: - Layout

extension TestModeModalViewController {
  func layoutUI() {
    view.addSubview(titleLabel)
    view.addSubview(reasonLabel)
    view.addSubview(scrollView)
    view.addSubview(resetButton)
    view.addSubview(okButton)

    scrollView.addSubview(contentStackView)

    // Add table view to stack
    contentStackView.addArrangedSubview(tableView)

    // Add entitlements section if there are entitlements
    if !availableEntitlements.isEmpty {
      let entitlementsHeader = UIStackView(
        arrangedSubviews: [entitlementsSectionLabel, entitlementsDescriptionLabel]
      )
      entitlementsHeader.axis = .vertical
      entitlementsHeader.spacing = 4
      entitlementsHeader.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
      entitlementsHeader.isLayoutMarginsRelativeArrangement = true

      let stackWrapper = UIView()
      stackWrapper.translatesAutoresizingMaskIntoConstraints = false
      stackWrapper.addSubview(entitlementsStackView)
      NSLayoutConstraint.activate([
        entitlementsStackView.topAnchor.constraint(equalTo: stackWrapper.topAnchor),
        entitlementsStackView.leadingAnchor.constraint(
          equalTo: stackWrapper.leadingAnchor,
          constant: 16
        ),
        entitlementsStackView.trailingAnchor.constraint(
          equalTo: stackWrapper.trailingAnchor,
          constant: -16
        ),
        entitlementsStackView.bottomAnchor.constraint(equalTo: stackWrapper.bottomAnchor)
      ])

      contentStackView.addArrangedSubview(entitlementsHeader)
      contentStackView.addArrangedSubview(stackWrapper)
    }

    tableViewHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 200)
    tableViewHeightConstraint?.isActive = true

    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
      titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

      reasonLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
      reasonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      reasonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

      scrollView.topAnchor.constraint(equalTo: reasonLabel.bottomAnchor, constant: 20),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: resetButton.topAnchor, constant: -16),

      contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
      contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
      contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

      resetButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      resetButton.bottomAnchor.constraint(equalTo: okButton.topAnchor, constant: -20),

      okButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      okButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      okButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
      okButton.heightAnchor.constraint(equalToConstant: 48)
    ])
  }

  func updateTableViewHeight() {
    tableView.layoutIfNeeded()
    let height = tableView.contentSize.height
    tableViewHeightConstraint?.constant = height
  }

  func setupEntitlementRows() {
    let savedSettings = loadSavedSettings()

    for entitlementId in availableEntitlements {
      let initialSelection = savedSettings[entitlementId]
      let rowView = EntitlementRowView(
        entitlementId: entitlementId,
        initialSelection: initialSelection
      )
      rowView.onSelectionChanged = { [weak self] id, selection in
        if selection.state != nil {
          self?.selectedEntitlements[id] = selection
        } else {
          self?.selectedEntitlements.removeValue(forKey: id)
        }
      }
      entitlementsStackView.addArrangedSubview(rowView)
      entitlementRowViews.append(rowView)
    }
  }
}
#endif
