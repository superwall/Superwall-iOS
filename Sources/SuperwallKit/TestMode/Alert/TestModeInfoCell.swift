//
//  TestModeInfoCell.swift
//  Superwall
//
//  Created by Claude on 2026-02-05.
//

import UIKit

/// A cell displaying a label, detail text, and optional copy/view buttons.
final class TestModeInfoCell: UITableViewCell {
  static let reuseId = "TestModeInfoCell"

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .boldSystemFont(ofSize: 13)
    label.textColor = primaryColor
    return label
  }()

  private let detailLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 14)
    label.textColor = .white
    label.numberOfLines = 0
    return label
  }()

  private let buttonsStack: UIStackView = {
    let stack = UIStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .horizontal
    stack.spacing = 12
    return stack
  }()

  private let viewButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("View", for: .normal)
    button.setTitleColor(primaryColor, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
    button.isHidden = true
    return button
  }()

  private let copyButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Copy", for: .normal)
    button.setTitleColor(primaryColor, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
    button.isHidden = true
    return button
  }()

  private var copyValue: String?
  private var linkURL: URL?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    backgroundColor = .clear
    contentView.backgroundColor = .clear
    selectionStyle = .none

    let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
    textStack.axis = .vertical
    textStack.spacing = 4
    textStack.translatesAutoresizingMaskIntoConstraints = false

    buttonsStack.addArrangedSubview(viewButton)
    buttonsStack.addArrangedSubview(copyButton)

    contentView.addSubview(textStack)
    contentView.addSubview(buttonsStack)

    buttonsStack.setContentHuggingPriority(.required, for: .horizontal)
    buttonsStack.setContentCompressionResistancePriority(.required, for: .horizontal)

    NSLayoutConstraint.activate([
      textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
      textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
      textStack.trailingAnchor.constraint(lessThanOrEqualTo: buttonsStack.leadingAnchor, constant: -8),

      buttonsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      buttonsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
    ])

    viewButton.addTarget(self, action: #selector(viewTapped), for: .touchUpInside)
    copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(
    label: String,
    detail: String,
    copyValue: String?,
    linkURL: URL?,
    hasNavigation: Bool = false
  ) {
    titleLabel.text = label
    detailLabel.text = detail
    self.copyValue = copyValue
    self.linkURL = linkURL
    copyButton.isHidden = copyValue == nil
    viewButton.isHidden = linkURL == nil

    if hasNavigation {
      let chevron = UIImageView()
      if #available(iOS 13.0, *) {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: config)
      }
      chevron.tintColor = primaryColor
      chevron.sizeToFit()
      accessoryView = chevron
      selectionStyle = .default
    } else {
      accessoryView = nil
      selectionStyle = .none
    }
  }

  @objc private func viewTapped() {
    guard let linkURL = linkURL else { return }
    UIApplication.shared.open(linkURL)
  }

  @objc private func copyTapped() {
    UIPasteboard.general.string = copyValue
    copyButton.setTitle("Copied!", for: .normal)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      self?.copyButton.setTitle("Copy", for: .normal)
    }
  }
}
