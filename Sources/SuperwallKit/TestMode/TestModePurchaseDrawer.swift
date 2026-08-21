//
//  TestModePurchaseDrawer.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//
// swiftlint:disable file_length

import UIKit

/// The result of a test mode purchase interaction.
enum TestModePurchaseResult {
  /// User chose to simulate a successful purchase.
  case purchased
  /// User chose to abandon the purchase.
  case abandoned
  /// User chose to simulate a purchase failure.
  case failed
}

/// Presents a bottom sheet for test mode purchases instead of calling StoreKit.
///
/// Shows three options: Purchase, Abandon, Failure — each fires the same
/// events as a real transaction would.
enum TestModePurchaseDrawer {
  @MainActor
  static func present(
    product: StoreProduct,
    entitlements: [String],
    showFreeTrial: Bool,
    from viewController: UIViewController,
    completion: @escaping (TestModePurchaseResult) -> Void
  ) {
    let modal = TestModePurchaseViewController(
      product: product,
      entitlements: entitlements,
      showFreeTrial: showFreeTrial,
      completion: completion
    )
    modal.modalPresentationStyle = .pageSheet
    #if !os(visionOS)
    if #available(iOS 15.0, *) {
      if let sheet = modal.sheetPresentationController {
        sheet.detents = [.medium()]
        sheet.prefersGrabberVisible = false
      }
    }
    #endif
    viewController.present(modal, animated: true)
  }
}

// MARK: - TestModePurchaseViewController

// swiftlint:disable:next type_body_length
private final class TestModePurchaseViewController: UIViewController {
  private let product: StoreProduct
  private let entitlements: [String]
  private let showFreeTrial: Bool
  private let completion: (TestModePurchaseResult) -> Void
  private var didComplete = false

  // MARK: - Header Views

  private static let darkBackgroundColor = UIColor(red: 13 / 255, green: 15 / 255, blue: 18 / 255, alpha: 1)

  private lazy var headerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = Self.darkBackgroundColor
    return view
  }()

  private lazy var logoImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.image = UIImage(
      named: "SuperwallKit_superwall_logo",
      in: Bundle.module,
      compatibleWith: nil
    )
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()

  private lazy var closeButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
    let xImage = UIImage(systemName: "xmark", withConfiguration: config)
    button.setImage(xImage, for: .normal)
    button.tintColor = UIColor.white.withAlphaComponent(0.7)
    button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
    button.layer.cornerRadius = 18
    button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    return button
  }()

  // MARK: - Product Card

  private lazy var productCard: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .secondarySystemGroupedBackground
    view.layer.cornerRadius = 20
    return view
  }()

  private lazy var productIdTitleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Product Identifier"
    label.textColor = .secondaryLabel
    label.font = .systemFont(ofSize: 11)
    return label
  }()

  private lazy var productIdLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = product.productIdentifier
    label.textColor = .label
    label.font = .systemFont(ofSize: 17, weight: .semibold)
    label.numberOfLines = 0
    return label
  }()

  private lazy var dividerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .separator
    return view
  }()

  private lazy var trialLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    if showFreeTrial {
      label.text = "\(product.trialPeriodText) free trial"
      label.isHidden = false
    } else {
      label.isHidden = true
    }
    label.textColor = .label
    label.font = .systemFont(ofSize: 17, weight: .bold)
    return label
  }()

  private lazy var thenLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "then"
    label.textColor = .secondaryLabel
    label.font = .systemFont(ofSize: 13)
    label.isHidden = !showFreeTrial
    return label
  }()

  private lazy var priceLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    var priceText = product.localizedPrice
    let period = product.period
    if !period.isEmpty {
      priceText += " per \(period)"
    }
    label.text = priceText
    label.textColor = .label
    label.font = .systemFont(ofSize: 17, weight: .bold)
    return label
  }()

  private lazy var oneTimeChargeLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "One-time charge"
    label.textColor = .secondaryLabel
    label.font = .systemFont(ofSize: 13)
    label.isHidden = !product.period.isEmpty
    return label
  }()

  private lazy var secondDividerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .separator
    return view
  }()

  private lazy var entitlementsTitleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = entitlements.count == 1 ? "Unlocks Entitlement" : "Unlocks Entitlements"
    label.textColor = .secondaryLabel
    label.font = .systemFont(ofSize: 11)
    return label
  }()

  private lazy var entitlementsLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    if entitlements.isEmpty {
      label.text = "No entitlements"
      label.textColor = .secondaryLabel
    } else {
      label.text = entitlements.joined(separator: ", ")
      label.textColor = .label
    }
    label.font = .systemFont(ofSize: 15, weight: .medium)
    label.numberOfLines = 0
    return label
  }()

  // MARK: - Action Buttons

  private lazy var purchaseButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    let title = showFreeTrial ? "Start Free Trial" : "Confirm Purchase"
    button.setTitle(title, for: .normal)
    button.setTitleColor(.white, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    button.backgroundColor = UIColor.systemBlue
    button.layer.cornerRadius = 12
    button.addTarget(self, action: #selector(purchaseTapped), for: .touchUpInside)
    return button
  }()

  private lazy var failureButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("Simulate Failure", for: .normal)
    button.setTitleColor(.systemRed, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
    button.backgroundColor = .clear
    button.addTarget(self, action: #selector(failureTapped), for: .touchUpInside)
    return button
  }()

  private lazy var disclaimerLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "This is a simulated purchase. No real transaction will occur."
    label.textColor = .tertiaryLabel
    label.font = .systemFont(ofSize: 12)
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()

  // MARK: - Init

  init(
    product: StoreProduct,
    entitlements: [String],
    showFreeTrial: Bool,
    completion: @escaping (TestModePurchaseResult) -> Void
  ) {
    self.product = product
    self.entitlements = entitlements
    self.showFreeTrial = showFreeTrial
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private lazy var blurView: UIVisualEffectView = {
    let blur = UIBlurEffect(style: .systemThinMaterial)
    let view = UIVisualEffectView(effect: blur)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    setupBlurBackground()
    presentationController?.delegate = self
    layoutUI()
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

  // swiftlint:disable:next function_body_length
  private func layoutUI() {
    // Add header container with logo left, close button right
    view.addSubview(headerView)
    headerView.addSubview(logoImageView)
    headerView.addSubview(closeButton)

    // Add product card and its contents
    view.addSubview(productCard)
    productCard.addSubview(productIdTitleLabel)
    productCard.addSubview(productIdLabel)
    productCard.addSubview(dividerView)
    productCard.addSubview(trialLabel)
    productCard.addSubview(thenLabel)
    productCard.addSubview(priceLabel)
    productCard.addSubview(oneTimeChargeLabel)
    productCard.addSubview(secondDividerView)
    productCard.addSubview(entitlementsTitleLabel)
    productCard.addSubview(entitlementsLabel)

    // Add action buttons
    view.addSubview(purchaseButton)
    view.addSubview(failureButton)
    view.addSubview(disclaimerLabel)

    NSLayoutConstraint.activate([
      // Header container - spans full width at top
      headerView.topAnchor.constraint(equalTo: view.topAnchor),
      headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

      // Superwall logo - left
      logoImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
      logoImageView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
      logoImageView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
      logoImageView.widthAnchor.constraint(equalToConstant: 120),
      logoImageView.heightAnchor.constraint(equalToConstant: 38),

      // Close button - right side of header
      closeButton.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
      closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
      closeButton.widthAnchor.constraint(equalToConstant: 36),
      closeButton.heightAnchor.constraint(equalToConstant: 36),

      // Product card
      productCard.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
      productCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      productCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

      // Product ID title
      productIdTitleLabel.topAnchor.constraint(equalTo: productCard.topAnchor, constant: 16),
      productIdTitleLabel.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      productIdTitleLabel.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),

      // Product ID
      productIdLabel.topAnchor.constraint(equalTo: productIdTitleLabel.bottomAnchor, constant: 2),
      productIdLabel.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      productIdLabel.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),

      // Divider
      dividerView.topAnchor.constraint(equalTo: productIdLabel.bottomAnchor, constant: 12),
      dividerView.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      dividerView.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),
      dividerView.heightAnchor.constraint(equalToConstant: 1),

      // Trial label
      trialLabel.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 12),
      trialLabel.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      trialLabel.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),

      // Then label
      thenLabel.topAnchor.constraint(equalTo: trialLabel.bottomAnchor, constant: 6),
      thenLabel.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      thenLabel.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),

      // Price - positioned below then label or divider depending on trial visibility
      priceLabel.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      priceLabel.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),

      // One-time charge label
      oneTimeChargeLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 2),
      oneTimeChargeLabel.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      oneTimeChargeLabel.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),

      // Second divider - position based on whether one-time charge is shown
      secondDividerView.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      secondDividerView.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),
      secondDividerView.heightAnchor.constraint(equalToConstant: 1),

      // Entitlements title
      entitlementsTitleLabel.topAnchor.constraint(equalTo: secondDividerView.bottomAnchor, constant: 12),
      entitlementsTitleLabel.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      entitlementsTitleLabel.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),

      // Entitlements
      entitlementsLabel.topAnchor.constraint(equalTo: entitlementsTitleLabel.bottomAnchor, constant: 2),
      entitlementsLabel.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 16),
      entitlementsLabel.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -16),
      entitlementsLabel.bottomAnchor.constraint(equalTo: productCard.bottomAnchor, constant: -16),

      // Purchase button
      purchaseButton.topAnchor.constraint(equalTo: productCard.bottomAnchor, constant: 20),
      purchaseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      purchaseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      purchaseButton.heightAnchor.constraint(equalToConstant: 50),

      // Failure button
      failureButton.topAnchor.constraint(equalTo: purchaseButton.bottomAnchor, constant: 8),
      failureButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      failureButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      failureButton.heightAnchor.constraint(equalToConstant: 44),

      // Disclaimer label
      disclaimerLabel.topAnchor.constraint(equalTo: failureButton.bottomAnchor, constant: 12),
      disclaimerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      disclaimerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
    ])

    // Position price label based on whether trial is shown
    if showFreeTrial {
      priceLabel.topAnchor.constraint(
        equalTo: thenLabel.bottomAnchor,
        constant: 6
      ).isActive = true
    } else {
      priceLabel.topAnchor.constraint(
        equalTo: dividerView.bottomAnchor,
        constant: 12
      ).isActive = true
    }

    // Position second divider based on whether one-time charge is shown
    if product.period.isEmpty {
      // One-time purchase: position below oneTimeChargeLabel
      secondDividerView.topAnchor.constraint(
        equalTo: oneTimeChargeLabel.bottomAnchor,
        constant: 12
      ).isActive = true
    } else {
      // Subscription: position directly below priceLabel
      secondDividerView.topAnchor.constraint(
        equalTo: priceLabel.bottomAnchor,
        constant: 12
      ).isActive = true
    }
  }

  // MARK: - Actions

  @objc private func closeTapped() {
    didComplete = true
    dismiss(animated: true) { [weak self] in
      self?.completion(.abandoned)
    }
  }

  @objc private func purchaseTapped() {
    didComplete = true
    dismiss(animated: true) { [weak self] in
      self?.completion(.purchased)
    }
  }

  @objc private func failureTapped() {
    didComplete = true
    dismiss(animated: true) { [weak self] in
      self?.completion(.failed)
    }
  }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension TestModePurchaseViewController: UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    // Called when user dismisses by tapping outside or swiping down
    if !didComplete {
      completion(.abandoned)
    }
  }
}
