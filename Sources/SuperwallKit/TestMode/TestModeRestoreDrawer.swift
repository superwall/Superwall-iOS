//
//  TestModeRestoreDrawer.swift
//  Superwall
//
//  Created by Claude on 2026-02-09.
//
import UIKit

/// The result of a test mode restore interaction.
enum TestModeRestoreResult {
  /// User chose to restore with the selected entitlements.
  case restored(Set<Entitlement>)
  /// User cancelled the restore.
  case cancelled
}

/// Presents a bottom sheet for test mode restores with entitlement selection.
enum TestModeRestoreDrawer {
  @MainActor
  static func present(
    availableEntitlements: [String],
    from viewController: UIViewController,
    completion: @escaping (TestModeRestoreResult) -> Void
  ) {
    let modal = TestModeRestoreViewController(
      availableEntitlements: availableEntitlements,
      completion: completion
    )
    modal.modalPresentationStyle = .pageSheet
    #if !os(visionOS)
    if #available(iOS 15.0, *) {
      if let sheet = modal.sheetPresentationController {
        sheet.detents = [.medium(), .large()]
        sheet.prefersGrabberVisible = false
      }
    }
    #endif
    viewController.present(modal, animated: true)
  }
}

// MARK: - TestModeRestoreViewController

private final class TestModeRestoreViewController: UIViewController {
  private let availableEntitlements: [String]
  private let completion: (TestModeRestoreResult) -> Void
  private var didComplete = false
  private var selectedEntitlements: [String: EntitlementSelection] = [:]
  private var entitlementRowViews: [EntitlementRowView] = []

  // MARK: - Header Views

  private lazy var testModeLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "\u{1F9EA} Test Mode"
    label.textColor = .white
    label.font = .systemFont(ofSize: 20, weight: .semibold)
    return label
  }()

  private lazy var closeButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
    let xImage = UIImage(systemName: "xmark", withConfiguration: config)
    button.setImage(xImage, for: .normal)
    button.tintColor = UIColor.white.withAlphaComponent(0.6)
    button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
    button.layer.cornerRadius = 18
    button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    return button
  }()

  private lazy var subtitleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Simulate Restore"
    label.textColor = UIColor.white.withAlphaComponent(0.6)
    label.font = .systemFont(ofSize: 15)
    return label
  }()

  private lazy var explainerLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Select which entitlements you want to restore (if any):"
    label.textColor = UIColor.white.withAlphaComponent(0.7)
    label.font = .systemFont(ofSize: 14)
    label.numberOfLines = 0
    return label
  }()

  // MARK: - Scroll View

  private lazy var scrollView: UIScrollView = {
    let scroll = UIScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.showsVerticalScrollIndicator = true
    return scroll
  }()

  private lazy var entitlementsStackView: UIStackView = {
    let stack = UIStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.spacing = 8
    return stack
  }()

  // MARK: - Action Buttons

  private lazy var restoreButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Restore", for: .normal)
    button.setTitleColor(primaryColor, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    button.backgroundColor = primaryButtonBackgroundColor
    button.layer.cornerRadius = 12
    button.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
    return button
  }()

  private lazy var disclaimerLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "This is a simulated restore. No real transaction will occur."
    label.textColor = UIColor.white.withAlphaComponent(0.4)
    label.font = .systemFont(ofSize: 12)
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()

  // MARK: - Init

  init(
    availableEntitlements: [String],
    completion: @escaping (TestModeRestoreResult) -> Void
  ) {
    self.availableEntitlements = availableEntitlements
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private lazy var blurView: UIVisualEffectView = {
    let blur = UIBlurEffect(style: .systemThinMaterialDark)
    let view = UIVisualEffectView(effect: blur)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = darkBackgroundColor
    setupBlurBackground()
    presentationController?.delegate = self
    layoutUI()
    setupEntitlementRows()
  }

  private func setupBlurBackground() {
    view.addSubview(blurView)
    NSLayoutConstraint.activate([
      blurView.topAnchor.constraint(equalTo: view.topAnchor),
      blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  // MARK: - Layout

  private func layoutUI() {
    view.addSubview(testModeLabel)
    view.addSubview(closeButton)
    view.addSubview(subtitleLabel)
    view.addSubview(explainerLabel)
    view.addSubview(scrollView)
    scrollView.addSubview(entitlementsStackView)
    view.addSubview(restoreButton)
    view.addSubview(disclaimerLabel)

    NSLayoutConstraint.activate([
      // Test Mode label - top left
      testModeLabel.topAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.topAnchor,
        constant: 28
      ),
      testModeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

      // Close button - top right
      closeButton.centerYAnchor.constraint(equalTo: testModeLabel.centerYAnchor),
      closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      closeButton.widthAnchor.constraint(equalToConstant: 36),
      closeButton.heightAnchor.constraint(equalToConstant: 36),

      // Subtitle
      subtitleLabel.topAnchor.constraint(equalTo: testModeLabel.bottomAnchor, constant: 4),
      subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

      // Explainer
      explainerLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
      explainerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      explainerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

      // Scroll view
      scrollView.topAnchor.constraint(equalTo: explainerLabel.bottomAnchor, constant: 12),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: restoreButton.topAnchor, constant: -16),

      // Entitlements stack inside scroll view
      entitlementsStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      entitlementsStackView.leadingAnchor.constraint(
        equalTo: scrollView.leadingAnchor,
        constant: 16
      ),
      entitlementsStackView.trailingAnchor.constraint(
        equalTo: scrollView.trailingAnchor,
        constant: -16
      ),
      entitlementsStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      entitlementsStackView.widthAnchor.constraint(
        equalTo: scrollView.widthAnchor,
        constant: -32
      ),

      // Restore button
      restoreButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      restoreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      restoreButton.heightAnchor.constraint(equalToConstant: 50),

      // Disclaimer label
      disclaimerLabel.topAnchor.constraint(
        equalTo: restoreButton.bottomAnchor,
        constant: 12
      ),
      disclaimerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      disclaimerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      disclaimerLabel.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor,
        constant: -16
      )
    ])
  }

  private func setupEntitlementRows() {
    for entitlementId in availableEntitlements {
      let rowView = EntitlementRowView(entitlementId: entitlementId)
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

  // MARK: - Building Entitlements

  private func buildEntitlements() -> Set<Entitlement> {
    var entitlements: Set<Entitlement> = []
    for (entitlementId, selection) in selectedEntitlements {
      guard let state = selection.state else { continue }
      let isActive = state == .subscribed
        || state == .inGracePeriod
        || state == .inBillingRetryPeriod
      let entitlement = Entitlement(
        id: entitlementId,
        type: .serviceLevel,
        isActive: isActive,
        store: .appStore,
        state: state,
        offerType: selection.offerType
      )
      entitlements.insert(entitlement)
    }
    return entitlements
  }

  // MARK: - Actions

  @objc private func closeTapped() {
    didComplete = true
    dismiss(animated: true) { [weak self] in
      self?.completion(.cancelled)
    }
  }

  @objc private func restoreTapped() {
    didComplete = true
    let entitlements = buildEntitlements()
    dismiss(animated: true) { [weak self] in
      self?.completion(.restored(entitlements))
    }
  }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension TestModeRestoreViewController: UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    if !didComplete {
      completion(.cancelled)
    }
  }
}
