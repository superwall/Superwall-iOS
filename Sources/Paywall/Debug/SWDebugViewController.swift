//
//  File.swift
//  
//
//  Created by Jake Mor on 8/26/21.
//
// swiftlint:disable:all force_unwrapping

import UIKit
import Foundation
import StoreKit
import Combine

var primaryColor = UIColor(hexString: "#75FFF1")
var primaryButtonBackgroundColor = UIColor(hexString: "#203133")
var secondaryButtonBackgroundColor = UIColor(hexString: "#44494F")
var lightBackgroundColor = UIColor(hexString: "#181A1E")
var darkBackgroundColor = UIColor(hexString: "#0D0F12")

struct AlertOption {
  var title: String? = ""
  var action: (@MainActor () -> Void)?
  var style: UIAlertAction.Style = .default
}

// swiftlint:disable:all type_body_length
@MainActor
final class SWDebugViewController: UIViewController {
  var logoImageView: UIImageView = {
    let superwallLogo = UIImage(named: "superwall_logo", in: Bundle.module, compatibleWith: nil)!
    let imageView = UIImageView(image: superwallLogo)
    imageView.contentMode = .scaleAspectFit
    imageView.backgroundColor = .clear
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.isHidden = false
    return imageView
  }()

  lazy var exitButton: SWBounceButton = {
    let button = SWBounceButton()
    let image = UIImage(named: "exit", in: Bundle.module, compatibleWith: nil)!
    button.setImage(image, for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.imageView?.tintColor = UIColor.white.withAlphaComponent(0.5)
    button.addTarget(self, action: #selector(pressedExitButton), for: .primaryActionTriggered)
    return button
  }()

  lazy var consoleButton: SWBounceButton = {
    let button = SWBounceButton()
    let image = UIImage(named: "debugger", in: Bundle.module, compatibleWith: nil)!
    button.setImage(image, for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.imageView?.tintColor = UIColor.white.withAlphaComponent(0.5)
    button.addTarget(self, action: #selector(pressedConsoleButton), for: .primaryActionTriggered)
    return button
  }()

  lazy var bottomButton: SWBounceButton = {
    let button = SWBounceButton()
    button.setTitle("Preview", for: .normal)
    button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    button.backgroundColor = primaryButtonBackgroundColor
    button.setTitleColor(primaryColor, for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false

    let image = UIImage(named: "play_button", in: Bundle.module, compatibleWith: nil)!
    button.titleEdgeInsets = UIEdgeInsets(top: -1, left: 0, bottom: 0, right: 0)
    // button.imageEdgeInsets = UIEdgeInsets(top: 1, left: 5, bottom: -1, right: -3)
    button.setImage(image, for: .normal)
    button.imageView?.tintColor = primaryColor
    button.layer.cornerCurve = .continuous
    button.layer.cornerRadius = 64.0 / 3
    button.addTarget(self, action: #selector(pressedBottomButton), for: .primaryActionTriggered)
    return button
  }()

  lazy var previewPickerButton: SWBounceButton = {
    let button = SWBounceButton()
    button.setTitle("", for: .normal)
    button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
    button.backgroundColor = lightBackgroundColor
    button.setTitleColor(primaryColor, for: .normal)
    button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.imageView?.tintColor = primaryColor
    button.layer.cornerRadius = 10

    let image = UIImage(named: "down_arrow", in: Bundle.module, compatibleWith: nil)!
    button.semanticContentAttribute = .forceRightToLeft
    button.setImage(image, for: .normal)
    button.imageView?.tintColor = primaryColor
    button.addTarget(self, action: #selector(pressedPreview), for: .primaryActionTriggered)
    return button
  }()

  private let activityIndicator: UIActivityIndicatorView = {
    let view = UIActivityIndicatorView()
    view.hidesWhenStopped = true
    view.startAnimating()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.style = .large
    view.color = primaryColor
    return view
  }()

  lazy var previewContainerView: SWBounceButton = {
    let button = SWBounceButton()
    button.shouldAnimateLightly = true
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(pressedPreview), for: .primaryActionTriggered)
    return button
  }()

  var paywallDatabaseId: String?
	var paywallIdentifier: String?
  var paywallResponse: PaywallResponse?
  var paywallResponses: [PaywallResponse] = []
  var previewViewContent: UIView?
  private var cancellable: AnyCancellable?

  init() {
    super.init(nibName: nil, bundle: nil)
    overrideUserInterfaceStyle = .dark
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    addSubviews()
    Task { await loadPreview() }
  }

  private func addSubviews() {
    view.addSubview(previewContainerView)
    view.addSubview(activityIndicator)
    view.addSubview(logoImageView)
    view.addSubview(consoleButton)
    view.addSubview(exitButton)
    view.addSubview(bottomButton)
    previewContainerView.addSubview(previewPickerButton)
    view.backgroundColor = lightBackgroundColor

    previewContainerView.clipsToBounds = false

    NSLayoutConstraint.activate([
      previewContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      previewContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      previewContainerView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 25),
      previewContainerView.bottomAnchor.constraint(equalTo: bottomButton.topAnchor, constant: -30),

      logoImageView.widthAnchor.constraint(equalTo: view.layoutMarginsGuide.widthAnchor, constant: -10),
      logoImageView.heightAnchor.constraint(equalToConstant: 20),
      logoImageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 20),
      logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

      consoleButton.centerXAnchor.constraint(equalTo: bottomButton.leadingAnchor),
      consoleButton.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),

      exitButton.centerXAnchor.constraint(equalTo: bottomButton.trailingAnchor),
      exitButton.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),

      activityIndicator.centerYAnchor.constraint(equalTo: previewContainerView.centerYAnchor),
      activityIndicator.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor),

      bottomButton.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor),
      bottomButton.heightAnchor.constraint(equalToConstant: 64),
      bottomButton.widthAnchor.constraint(equalTo: view.layoutMarginsGuide.widthAnchor, constant: -40),
      bottomButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: -10),

      previewPickerButton.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor, constant: 0),
      previewPickerButton.heightAnchor.constraint(equalToConstant: 26),
      previewPickerButton.centerYAnchor.constraint(equalTo: previewContainerView.bottomAnchor)
    ])
  }

  func loadPreview() async {
    activityIndicator.startAnimating()
    previewViewContent?.removeFromSuperview()

    if paywallResponses.isEmpty {
      do {
        let response = try await Network.shared.getPaywalls()
        paywallResponses = response.paywalls
        await finishLoadingPreview()
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .debugViewController,
          message: "Failed to Fetch Paywalls",
          error: error
        )
      }
    } else {
      await finishLoadingPreview()
    }
  }

	func finishLoadingPreview() async {
		var paywallId: String?

		if let paywallIdentifier = paywallIdentifier {
			paywallId = paywallIdentifier
		} else if let paywallDatabaseId = paywallDatabaseId {
			paywallId = paywallResponses.first(where: { $0.id == paywallDatabaseId })?.identifier
			paywallIdentifier = paywallId
		}

    // TODO: Can PaywallId actually be nil here or just a state error?
    guard let paywallId = paywallId else {
      return
    }

    do {
      let request = PaywallRequest(responseIdentifiers: .init(paywallId: paywallId))
      let response = try await PaywallResponseManager.shared.getResponse(from: request)
      self.paywallResponse = response
      self.previewPickerButton.setTitle("\(response.name ?? "Preview")", for: .normal)

      StoreKitManager.shared.getVariables(forResponse: response) { variables in
        self.paywallResponse?.variables = variables
        onMain {
          self.activityIndicator.stopAnimating()
          self.addPaywallPreview()
        }
      }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .debugViewController,
        message: "No Paywall Response",
        info: nil,
        error: error
      )
    }
	}

  func addPaywallPreview() {
    guard let paywallResponse = paywallResponse else {
      return
    }

    let child = SWPaywallViewController(paywallResponse: paywallResponse)
    addChild(child)
    previewContainerView.insertSubview(child.view, at: 0)
    previewViewContent = child.view
    child.didMove(toParent: self)

    child.view.translatesAutoresizingMaskIntoConstraints = false
    child.view.isUserInteractionEnabled = false

    NSLayoutConstraint.activate([
      child.view.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.0),
      child.view.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1.0),
      child.view.centerYAnchor.constraint(equalTo: previewContainerView.centerYAnchor),
      child.view.centerXAnchor.constraint(equalTo: previewContainerView.centerXAnchor)
    ])

    child.view.clipsToBounds = true
    child.view.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
    child.view.layer.borderWidth = 1.0
    child.view.layer.cornerRadius = 52
    child.view.alpha = 0.0

    let ratio = previewContainerView.frame.size.height / view.frame.size.height

    child.view.transform = CGAffineTransform.identity.scaledBy(
      x: ratio,
      y: ratio
    )
    child.view.layer.cornerCurve = .continuous

    UIView.animate(
      withDuration: 0.25,
      delay: 0.1
    ) {
      child.view.alpha = 1.0
    }
  }

  @objc func pressedPreview() {
    guard let id = paywallDatabaseId else { return }

    let options: [AlertOption] = paywallResponses.map { response in
      var name = response.name ?? ""

      if id == response.id ?? "none" {
        name = "\(name) ✓"
      }

      let alert = AlertOption(
        title: name,
        action: { [weak self] in
          self?.paywallDatabaseId = response.id
          self?.paywallIdentifier = response.identifier
          Task { await self?.loadPreview() }
        },
        style: .default
      )
      return alert
    }

    presentAlert(title: nil, message: "Your Paywalls", options: options)
  }

  @objc func pressedExitButton() {
    Task {
      await SWDebugManager.shared.closeDebugger(animated: false)
    }
  }

  @objc func pressedConsoleButton() {
    presentAlert(title: nil, message: "Menu", options: [
      AlertOption(title: "Localization", action: showLocalizationPicker, style: .default),
      AlertOption(title: "Templates", action: showConsole, style: .default)
    ])
  }

	func showLocalizationPicker() {
		let viewController = SWLocalizationViewController { [weak self] locale in
			LocalizationManager.shared.selectedLocale = locale
      Task { await self?.loadPreview() }
		}

		let navController = UINavigationController(rootViewController: viewController)
		self.present(navController, animated: true)
	}

	func showConsole() {
		if let paywallResponse = paywallResponse {
			StoreKitManager.shared.getProducts(withIds: paywallResponse.productIds) { [weak self] result in
        switch result {
        case .success(let output):
          onMain {
            var products: [SKProduct] = []

            for id in paywallResponse.productIds {
              if let product = output.productsById[id] {
                products.append(product)
              }
            }

            let viewController = SWConsoleViewController(products: products)
            let navController = UINavigationController(rootViewController: viewController)
            navController.modalPresentationStyle = .overFullScreen
            self?.present(navController, animated: true)
          }
        case .failure:
          break
        }
			}
		} else {
			Logger.debug(
        logLevel: .error,
        scope: .debugViewController,
        message: "Paywall Response is Nil",
        info: nil,
        error: nil
      )
		}
	}

  @objc func pressedBottomButton() {
    presentAlert(
      title: nil,
      message: "Which version?",
      options: [
        AlertOption(
          title: "With Free Trial",
          action: { [weak self] in
            self?.loadAndShowPaywall(freeTrialAvailable: true)
          },
          style: .default
        ),
        AlertOption(
          title: "Without Free Trial",
          action: {  [weak self] in
            self?.loadAndShowPaywall(freeTrialAvailable: false)
          },
          style: .default
        )
      ]
    )
  }

  func loadAndShowPaywall(freeTrialAvailable: Bool = false) {
    guard let paywallIdentifier = paywallIdentifier else {
      return
    }

    Paywall.isFreeTrialAvailableOverride = freeTrialAvailable

    bottomButton.setImage(nil, for: .normal)
    bottomButton.showLoading = true

    let presentationRequest = PaywallPresentationRequest(
      presentationInfo: .fromIdentifier(paywallIdentifier),
      presentingViewController: self
    )

    cancellable = Paywall.shared.internallyPresent(presentationRequest)
      .sink { state in
        switch state {
        case .presented:
          self.bottomButton.showLoading = false

          let playButton = UIImage(named: "play_button", in: Bundle.module, compatibleWith: nil)!
          self.bottomButton.setImage(
            playButton,
            for: .normal
          )
        case .skipped(let reason):
          var errorMessage: String?

          switch reason {
          case .holdout:
            errorMessage = "The user was assigned to a holdout"
          case .noRuleMatch:
            errorMessage = "The user didn't match a rule"
          case .triggerNotFound:
            errorMessage = "Couldn't find trigger"
          case .error(let error):
            errorMessage = error.localizedDescription
            Logger.debug(
              logLevel: .error,
              scope: .debugViewController,
              message: "Failed to Show Paywall",
              info: nil
            )
          }
          self.presentAlert(title: "Paywall Skipped", message: errorMessage, options: [])
          self.bottomButton.showLoading = false

          let playButton = UIImage(named: "play_button", in: Bundle.module, compatibleWith: nil)!
          self.bottomButton.setImage(playButton, for: .normal)
          self.activityIndicator.stopAnimating()
        case .dismissed:
          break
        }
      }
  }

  var oldTintColor: UIColor? = UIColor.systemBlue

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let view = UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
    oldTintColor = view.tintColor
    view.tintColor = primaryColor
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    Task {
      await PaywallManager.shared.clearCache() // TODO: test if we need this
    }
    UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = oldTintColor
    SWDebugManager.shared.isDebuggerLaunched = false
    LocalizationManager.shared.selectedLocale = nil
  }
}

extension SWDebugViewController {
  func presentAlert(title: String?, message: String?, options: [AlertOption]) {
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
    alertController.overrideUserInterfaceStyle = .dark
    alertController.view.tintColor = primaryColor

    for option in options {
      let action = UIAlertAction(
        title: option.title,
        style: option.style
      ) { _ in
        option.action?()
      }
      alertController.addAction(action)
    }

    alertController.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
    alertController.view.tintColor = primaryColor

    present(
      alertController,
      animated: true
    ) {
      alertController.view.tintColor = primaryColor
    }
  }
  // swiftlint:disable:next file_length
}
