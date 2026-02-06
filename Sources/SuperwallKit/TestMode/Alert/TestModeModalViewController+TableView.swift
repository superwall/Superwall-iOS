//
//  TestModeModalViewController+TableView.swift
//  Superwall
//
//  Created by Claude on 2026-02-05.
//

import UIKit

/// Action type for a row in the test mode modal.
enum TestModeRowAction {
  case none
  case navigate(() -> UIViewController)
}

/// A row of info displayed in the test mode modal.
struct TestModeInfoRow {
  let label: String
  let detail: String
  let copyValue: String?
  let linkURL: URL?
  var action: TestModeRowAction = .none
}

// MARK: - Free Trial Picker

extension TestModeModalViewController {
  func configureFreeTrialCell(_ cell: UITableViewCell) {
    cell.backgroundColor = .clear
    cell.contentView.backgroundColor = .clear
    cell.selectionStyle = .none

    // Remove existing subviews
    cell.contentView.subviews.forEach { $0.removeFromSuperview() }

    let titleLabel = UILabel()
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.text = "Free Trial Override"
    titleLabel.textColor = primaryColor
    titleLabel.font = .boldSystemFont(ofSize: 13)

    let detailLabel = UILabel()
    detailLabel.translatesAutoresizingMaskIntoConstraints = false
    detailLabel.text = "Override free trial availability"
    detailLabel.textColor = .white
    detailLabel.font = .systemFont(ofSize: 14)

    // Value button showing current selection with dropdown indicator
    let valueButton = UIButton(type: .system)
    valueButton.translatesAutoresizingMaskIntoConstraints = false
    valueButton.setTitle("\(selectedFreeTrialOverride.displayName) \u{25BE}", for: .normal)
    valueButton.setTitleColor(primaryColor, for: .normal)
    valueButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
    valueButton.contentHorizontalAlignment = .right

    if #available(iOS 14.0, *) {
      let actions = FreeTrialOverride.allCases.map { [weak self] option in
        UIAction(
          title: option.displayName,
          state: self?.selectedFreeTrialOverride == option ? .on : .off
        ) { [weak self] _ in
          self?.selectedFreeTrialOverride = option
          self?.reloadFreeTrialSection()
        }
      }
      valueButton.menu = UIMenu(children: actions)
      valueButton.showsMenuAsPrimaryAction = true
    } else {
      valueButton.addTarget(self, action: #selector(showFreeTrialActionSheet), for: .touchUpInside)
    }

    let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
    textStack.axis = .vertical
    textStack.spacing = 4
    textStack.translatesAutoresizingMaskIntoConstraints = false

    cell.contentView.addSubview(textStack)
    cell.contentView.addSubview(valueButton)

    NSLayoutConstraint.activate([
      textStack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
      textStack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
      textStack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      textStack.trailingAnchor.constraint(lessThanOrEqualTo: valueButton.leadingAnchor, constant: -8),

      valueButton.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
      valueButton.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
    ])
  }

  @objc func showFreeTrialActionSheet() {
    let alertController = UIAlertController(
      title: "Free Trial Override",
      message: nil,
      preferredStyle: .actionSheet
    )

    for option in FreeTrialOverride.allCases {
      let action = UIAlertAction(title: option.displayName, style: .default) { [weak self] _ in
        self?.selectedFreeTrialOverride = option
        self?.reloadFreeTrialSection()
      }
      alertController.addAction(action)
    }

    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alertController, animated: true)
  }
}

// MARK: - Row Building

extension TestModeModalViewController {
  func buildRows() {
    let baseUrl = networkEnvironment.dashboardBaseUrl
    let userLinkURL = URL(string: "\(baseUrl)/sdk-link/applications/\(apiKey)/users/\(userId)")
    rows.append(TestModeInfoRow(
      label: isIdentified ? "User ID" : "Alias ID",
      detail: userId,
      copyValue: userId,
      linkURL: userLinkURL
    ))

    let purchaseControllerDetail: String
    if hasPurchaseController {
      purchaseControllerDetail = "Provided (not used in Test Mode)"
    } else {
      purchaseControllerDetail = "Not provided"
    }
    rows.append(TestModeInfoRow(
      label: "Purchase Controller",
      detail: purchaseControllerDetail,
      copyValue: nil,
      linkURL: nil
    ))

    rows.append(TestModeInfoRow(
      label: "Device Attributes",
      detail: "Tap to view",
      copyValue: nil,
      linkURL: nil,
      action: .navigate {
        DeviceAttributesViewController(showSection: .device)
      }
    ))

    rows.append(TestModeInfoRow(
      label: "User Attributes",
      detail: "Tap to view",
      copyValue: nil,
      linkURL: nil,
      action: .navigate {
        DeviceAttributesViewController(showSection: .user)
      }
    ))
  }
}

// MARK: - UITableViewDataSource & Delegate

extension TestModeModalViewController: UITableViewDataSource, UITableViewDelegate {
  private var freeTrialRowIndex: Int {
    rows.count
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // All info rows + 1 free trial row
    rows.count + 1
  }

  func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  ) -> UITableViewCell {
    // Last row is the free trial cell
    if indexPath.row == freeTrialRowIndex {
      let cell = tableView.dequeueReusableCell(
        withIdentifier: TestModeModalViewController.freeTrialCellId,
        for: indexPath
      )
      configureFreeTrialCell(cell)
      return cell
    }

    guard let cell = tableView.dequeueReusableCell(
      withIdentifier: TestModeInfoCell.reuseId,
      for: indexPath
    ) as? TestModeInfoCell else {
      return UITableViewCell()
    }
    let row = rows[indexPath.row]
    let hasNavigation: Bool
    if case .navigate = row.action {
      hasNavigation = true
    } else {
      hasNavigation = false
    }
    cell.configure(
      label: row.label,
      detail: row.detail,
      copyValue: row.copyValue,
      linkURL: row.linkURL,
      hasNavigation: hasNavigation
    )
    return cell
  }

  func tableView(
    _ tableView: UITableView,
    shouldHighlightRowAt indexPath: IndexPath
  ) -> Bool {
    if indexPath.row == freeTrialRowIndex {
      return false
    }
    let row = rows[indexPath.row]
    if case .navigate = row.action {
      return true
    }
    return false
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.row == freeTrialRowIndex {
      return
    }
    let row = rows[indexPath.row]
    if case .navigate(let viewControllerProvider) = row.action {
      let viewController = viewControllerProvider()
      navigationController?.pushViewController(viewController, animated: true)
    }
  }
}
