//
//  TestModeDeviceAttributesViewController.swift
//  Superwall
//
//  Created by Claude on 2026-02-05.
//

import UIKit

// MARK: - DeviceAttributesViewController

final class DeviceAttributesViewController: UIViewController {
  enum AttributeSection: Int, CaseIterable {
    case device
    case user

    var title: String {
      switch self {
      case .device: return "Device Attributes"
      case .user: return "User Attributes"
      }
    }
  }

  private let showSection: AttributeSection
  private var deviceAttributes: [(key: String, value: String)] = []
  private var userAttributes: [(key: String, value: String)] = []

  init(showSection: AttributeSection) {
    self.showSection = showSection
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private lazy var tableView: UITableView = {
    let table = UITableView(frame: .zero, style: .plain)
    table.translatesAutoresizingMaskIntoConstraints = false
    table.backgroundColor = .clear
    table.separatorColor = UIColor.white.withAlphaComponent(0.1)
    table.dataSource = self
    table.delegate = self
    table.register(DeviceAttributeCell.self, forCellReuseIdentifier: DeviceAttributeCell.reuseId)
    table.rowHeight = UITableView.automaticDimension
    table.estimatedRowHeight = 50
    return table
  }()

  private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = showSection.title
    label.textColor = .white
    label.font = .boldSystemFont(ofSize: 20)
    return label
  }()

  private lazy var backButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
    let image = UIImage(systemName: "chevron.left", withConfiguration: config)
    button.setImage(image, for: .normal)
    button.tintColor = primaryColor
    button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    return button
  }()

  private lazy var hintLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Tap an attribute to copy"
    label.textColor = UIColor.white.withAlphaComponent(0.6)
    label.font = .systemFont(ofSize: 13)
    return label
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = darkBackgroundColor
    setupUI()
    loadAttributes()
  }

  private func setupUI() {
    view.addSubview(backButton)
    view.addSubview(titleLabel)
    view.addSubview(hintLabel)
    view.addSubview(tableView)

    NSLayoutConstraint.activate([
      backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      backButton.widthAnchor.constraint(equalToConstant: 44),
      backButton.heightAnchor.constraint(equalToConstant: 44),

      titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
      titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),

      hintLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
      hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

      tableView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 12),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  private func loadAttributes() {
    Task {
      switch showSection {
      case .device:
        let deviceAttrs = await Superwall.shared.getDeviceAttributes()
        let sortedDeviceKeys = deviceAttrs.keys.sorted()
        self.deviceAttributes = sortedDeviceKeys.map { key in
          let value = deviceAttrs[key]
          let valueString = formatValue(value)
          return (key: key, value: valueString)
        }
      case .user:
        let userAttrs = Superwall.shared.userAttributes
        let sortedUserKeys = userAttrs.keys.sorted()
        self.userAttributes = sortedUserKeys.map { key in
          let value = userAttrs[key]
          let valueString = formatValue(value)
          return (key: key, value: valueString)
        }
      }

      await MainActor.run {
        self.tableView.reloadData()
      }
    }
  }

  private func formatValue(_ value: Any?) -> String {
    guard let value = value else {
      return "null"
    }

    if value is NSNull {
      return "null"
    }

    if let stringValue = value as? String {
      return stringValue
    }

    // Check Bool before NSNumber since Bool bridges to NSNumber
    if let boolValue = value as? Bool {
      return boolValue ? "true" : "false"
    }

    if let numberValue = value as? NSNumber {
      return numberValue.stringValue
    }

    if let arrayValue = value as? [Any] {
      let formattedItems = arrayValue.map { formatValue($0) }
      return "[\(formattedItems.joined(separator: ", "))]"
    }

    if let dictValue = value as? [String: Any] {
      let formattedPairs = dictValue.map { "\($0.key): \(formatValue($0.value))" }
      return "{\(formattedPairs.joined(separator: ", "))}"
    }

    // Fallback - use String(describing:) but clean up Optional wrapper if present
    let description = String(describing: value)
    if description.hasPrefix("Optional(") && description.hasSuffix(")") {
      let start = description.index(description.startIndex, offsetBy: 9)
      let end = description.index(description.endIndex, offsetBy: -1)
      return String(description[start..<end])
    }

    return description
  }

  @objc private func backTapped() {
    navigationController?.popViewController(animated: true)
  }
}

extension DeviceAttributesViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch showSection {
    case .device: return deviceAttributes.count
    case .user: return userAttributes.count
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(
      withIdentifier: DeviceAttributeCell.reuseId,
      for: indexPath
    ) as? DeviceAttributeCell else {
      return UITableViewCell()
    }
    let attribute: (key: String, value: String)
    switch showSection {
    case .device: attribute = deviceAttributes[indexPath.row]
    case .user: attribute = userAttributes[indexPath.row]
    }
    cell.configure(key: attribute.key, value: attribute.value)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let attribute: (key: String, value: String)
    switch showSection {
    case .device: attribute = deviceAttributes[indexPath.row]
    case .user: attribute = userAttributes[indexPath.row]
    }
    UIPasteboard.general.string = attribute.value
    showCopiedFeedback(for: indexPath)
  }

  private func showCopiedFeedback(for indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) as? DeviceAttributeCell else { return }
    cell.showCopiedFeedback()
  }
}

// MARK: - DeviceAttributeCell

final class DeviceAttributeCell: UITableViewCell {
  static let reuseId = "DeviceAttributeCell"

  private let keyLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 13, weight: .medium)
    label.textColor = primaryColor
    return label
  }()

  private let valueLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 14)
    label.textColor = .white
    label.numberOfLines = 0
    return label
  }()

  private var originalValue: String = ""

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    backgroundColor = .clear
    contentView.backgroundColor = .clear
    selectionStyle = .default

    let stack = UIStackView(arrangedSubviews: [keyLabel, valueLabel])
    stack.axis = .vertical
    stack.spacing = 2
    stack.translatesAutoresizingMaskIntoConstraints = false

    contentView.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(key: String, value: String) {
    keyLabel.text = key
    valueLabel.text = value
    originalValue = value
  }

  func showCopiedFeedback() {
    valueLabel.text = "Copied!"
    valueLabel.textColor = primaryColor
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.valueLabel.text = self?.originalValue
      self?.valueLabel.textColor = .white
    }
  }
}
