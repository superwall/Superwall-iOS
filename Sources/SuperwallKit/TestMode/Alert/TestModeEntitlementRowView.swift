//
//  TestModeEntitlementRowView.swift
//  Superwall
//
//  Created by Claude on 2026-02-05.
//

import UIKit

/// Represents the selected state for an entitlement, including "Inactive" option.
enum EntitlementStateOption: CaseIterable {
  case inactive
  case subscribed
  case inGracePeriod
  case inBillingRetryPeriod
  case expired
  case revoked

  var displayName: String {
    switch self {
    case .inactive:
      return "Inactive"
    case .subscribed:
      return "Subscribed"
    case .inGracePeriod:
      return "In Grace Period"
    case .inBillingRetryPeriod:
      return "Billing Retry"
    case .expired:
      return "Expired"
    case .revoked:
      return "Revoked"
    }
  }

  var subscriptionState: LatestSubscription.State? {
    switch self {
    case .inactive:
      return nil
    case .subscribed:
      return .subscribed
    case .inGracePeriod:
      return .inGracePeriod
    case .inBillingRetryPeriod:
      return .inBillingRetryPeriod
    case .expired:
      return .expired
    case .revoked:
      return .revoked
    }
  }
}

/// Represents the selected offer type for an entitlement.
enum OfferTypeOption: CaseIterable {
  case none
  case trial
  case code
  case promotional
  case winback

  var displayName: String {
    switch self {
    case .none:
      return "None"
    case .trial:
      return "Trial"
    case .code:
      return "Code"
    case .promotional:
      return "Promotional"
    case .winback:
      return "Winback"
    }
  }

  var offerType: LatestSubscription.OfferType? {
    switch self {
    case .none:
      return nil
    case .trial:
      return .trial
    case .code:
      return .code
    case .promotional:
      return .promotional
    case .winback:
      return .winback
    }
  }
}

/// Tracks the selected state and offer type for an entitlement.
struct EntitlementSelection {
  var state: LatestSubscription.State?
  var offerType: LatestSubscription.OfferType?
}

/// A row view for selecting entitlement state and offer type.
final class EntitlementRowView: UIView {
  private let entitlementId: String
  var onSelectionChanged: ((String, EntitlementSelection) -> Void)?

  private var selectedStateOption: EntitlementStateOption = .inactive {
    didSet {
      updateAppearance()
      updateStateButtonTitle()
      updateOfferTypeVisibility()
      notifySelectionChanged()
    }
  }

  private var selectedOfferType: OfferTypeOption = .none {
    didSet {
      updateOfferTypeButtonTitle()
      notifySelectionChanged()
    }
  }

  private lazy var containerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = UIColor.white.withAlphaComponent(0.08)
    view.layer.cornerRadius = 12
    return view
  }()

  private lazy var nameLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.textColor = .white
    label.font = .systemFont(ofSize: 15, weight: .medium)
    return label
  }()

  private lazy var buttonsStack: UIStackView = {
    let stack = UIStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .horizontal
    stack.spacing = 8
    stack.alignment = .center
    return stack
  }()

  private lazy var offerTypeButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
    button.contentHorizontalAlignment = .right
    button.isHidden = true
    return button
  }()

  private lazy var stateButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitleColor(primaryColor, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
    button.contentHorizontalAlignment = .right
    return button
  }()

  init(entitlementId: String, initialSelection: EntitlementSelection? = nil) {
    self.entitlementId = entitlementId
    super.init(frame: .zero)
    nameLabel.text = entitlementId
    setupUI()

    // Apply initial selection if provided
    if let selection = initialSelection {
      setSelection(selection, notify: false)
    }

    updateStateButtonTitle()
    updateOfferTypeButtonTitle()
    updateAppearance()
    updateOfferTypeVisibilityWithoutReset()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Sets the selection without triggering the onChange callback.
  func setSelection(_ selection: EntitlementSelection, notify: Bool = true) {
    // Convert state to option
    if let state = selection.state {
      selectedStateOption = EntitlementStateOption.allCases.first {
        $0.subscriptionState == state
      } ?? .inactive
    } else {
      selectedStateOption = .inactive
    }

    // Convert offer type to option
    if let offerType = selection.offerType {
      selectedOfferType = OfferTypeOption.allCases.first {
        $0.offerType == offerType
      } ?? .none
    } else {
      selectedOfferType = .none
    }

    // Update UI
    updateStateButtonTitle()
    updateOfferTypeButtonTitle()
    updateAppearance()
    updateOfferTypeVisibilityWithoutReset()
    if #available(iOS 14.0, *) {
      updateStateMenu()
      updateOfferTypeMenu()
    }

    if notify {
      notifySelectionChanged()
    }
  }

  /// Resets to default (inactive) state.
  func reset() {
    setSelection(EntitlementSelection(state: nil, offerType: nil), notify: true)
  }

  private func setupUI() {
    addSubview(containerView)
    containerView.addSubview(nameLabel)
    containerView.addSubview(buttonsStack)

    buttonsStack.addArrangedSubview(offerTypeButton)
    buttonsStack.addArrangedSubview(stateButton)

    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: topAnchor),
      containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

      nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
      nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

      buttonsStack.leadingAnchor.constraint(
        greaterThanOrEqualTo: nameLabel.trailingAnchor,
        constant: 8
      ),
      buttonsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
      buttonsStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

      containerView.heightAnchor.constraint(equalToConstant: 48)
    ])

    setupMenus()
  }

  private func setupMenus() {
    if #available(iOS 14.0, *) {
      updateStateMenu()
      updateOfferTypeMenu()
      stateButton.showsMenuAsPrimaryAction = true
      offerTypeButton.showsMenuAsPrimaryAction = true
    } else {
      stateButton.addTarget(self, action: #selector(showStateActionSheet), for: .touchUpInside)
      offerTypeButton.addTarget(
        self,
        action: #selector(showOfferTypeActionSheet),
        for: .touchUpInside
      )
    }
  }

  @available(iOS 14.0, *)
  private func updateStateMenu() {
    let actions = EntitlementStateOption.allCases.map { [weak self] option in
      UIAction(
        title: option.displayName,
        state: self?.selectedStateOption == option ? .on : .off
      ) { [weak self] _ in
        self?.selectedStateOption = option
        self?.updateStateMenu()
      }
    }
    stateButton.menu = UIMenu(children: actions)
  }

  @available(iOS 14.0, *)
  private func updateOfferTypeMenu() {
    let actions = OfferTypeOption.allCases.map { [weak self] option in
      UIAction(
        title: option.displayName,
        state: self?.selectedOfferType == option ? .on : .off
      ) { [weak self] _ in
        self?.selectedOfferType = option
        self?.updateOfferTypeMenu()
      }
    }
    offerTypeButton.menu = UIMenu(children: actions)
  }

  @objc private func showStateActionSheet() {
    guard let viewController = findViewController() else { return }

    let alertController = UIAlertController(
      title: "Select State",
      message: nil,
      preferredStyle: .actionSheet
    )

    for option in EntitlementStateOption.allCases {
      let action = UIAlertAction(title: option.displayName, style: .default) { [weak self] _ in
        self?.selectedStateOption = option
      }
      alertController.addAction(action)
    }

    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    viewController.present(alertController, animated: true)
  }

  @objc private func showOfferTypeActionSheet() {
    guard let viewController = findViewController() else { return }

    let alertController = UIAlertController(
      title: "Select Offer Type",
      message: nil,
      preferredStyle: .actionSheet
    )

    for option in OfferTypeOption.allCases {
      let action = UIAlertAction(title: option.displayName, style: .default) { [weak self] _ in
        self?.selectedOfferType = option
      }
      alertController.addAction(action)
    }

    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    viewController.present(alertController, animated: true)
  }

  private func findViewController() -> UIViewController? {
    var responder: UIResponder? = self
    while let nextResponder = responder?.next {
      if let viewController = nextResponder as? UIViewController {
        return viewController
      }
      responder = nextResponder
    }
    return nil
  }

  private func updateStateButtonTitle() {
    stateButton.setTitle(selectedStateOption.displayName + " \u{25BE}", for: .normal)
  }

  private func updateOfferTypeButtonTitle() {
    offerTypeButton.setTitle("Offer: " + selectedOfferType.displayName + " \u{25BE}", for: .normal)
  }

  private func updateOfferTypeVisibility() {
    // Only show offer type when state is not inactive
    offerTypeButton.isHidden = selectedStateOption == .inactive
    // Reset offer type when going to inactive
    if selectedStateOption == .inactive {
      selectedOfferType = .none
      // Update the menu to reflect the reset
      if #available(iOS 14.0, *) {
        updateOfferTypeMenu()
      }
    }
  }

  private func updateOfferTypeVisibilityWithoutReset() {
    // Only show offer type when state is not inactive (without resetting)
    offerTypeButton.isHidden = selectedStateOption == .inactive
  }

  private func updateAppearance() {
    if selectedStateOption == .inactive {
      containerView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
      containerView.layer.borderWidth = 0
    } else {
      containerView.backgroundColor = primaryColor.withAlphaComponent(0.15)
      containerView.layer.borderWidth = 1
      containerView.layer.borderColor = primaryColor.cgColor
    }
  }

  private func notifySelectionChanged() {
    let selection = EntitlementSelection(
      state: selectedStateOption.subscriptionState,
      offerType: selectedOfferType.offerType
    )
    onSelectionChanged?(entitlementId, selection)
  }
}
