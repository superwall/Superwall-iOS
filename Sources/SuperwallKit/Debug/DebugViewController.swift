//
//  File.swift
//  
//
//  Created by Jake Mor on 8/26/21.
//
// swiftlint:disable force_unwrapping file_length type_body_length function_body_length

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
  var action: (@MainActor () async -> Void)?
  var style: UIAlertAction.Style = .default
}

@MainActor
final class DebugViewController: UIViewController {
  var logoImageView: UIImageView = {
    let superwallLogo = UIImage(named: "SuperwallKit_superwall_logo", in: Bundle.module, compatibleWith: nil)!
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
    let image = UIImage(named: "SuperwallKit_exit", in: Bundle.module, compatibleWith: nil)!
    button.setImage(image, for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.imageView?.tintColor = UIColor.white.withAlphaComponent(0.5)
    button.addTarget(self, action: #selector(pressedExitButton), for: .primaryActionTriggered)
    return button
  }()

  lazy var consoleButton: SWBounceButton = {
    let button = SWBounceButton()
    let image = UIImage(named: "SuperwallKit_debugger", in: Bundle.module, compatibleWith: nil)!
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

    let image = UIImage(named: "SuperwallKit_play_button", in: Bundle.module, compatibleWith: nil)!
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
    button.titleLabel?.numberOfLines = 0
    button.titleLabel?.lineBreakMode = .byWordWrapping
    button.titleLabel?.textAlignment = .center
    button.backgroundColor = lightBackgroundColor
    button.setTitleColor(primaryColor, for: .normal)
    button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.imageView?.tintColor = primaryColor
    button.layer.cornerRadius = 10

    let image = UIImage(named: "SuperwallKit_down_arrow", in: Bundle.module, compatibleWith: nil)!
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
  var paywall: Paywall?

  /// Set when the debugger is opened from a `superwall dev` link: the surfaces
  /// that server exposes, and where to load them from.
  var devServer: (base: URL, surfaces: [DevServerSurface])?

  /// The dev-server surface to render instead of fetching a published paywall.
  private var devSurface: DevServerSurface?

  /// Backs the "Your Paywalls" picker.
  ///
  /// Populated from `GET /v2/paywalls/preview-list`. Empty when the request fails or the app
  /// has a single paywall, in which case the picker declines to open.
  var previewPaywalls: [PaywallSummary] = []
  var previewViewContent: UIView?
  private var cancellable: AnyCancellable?
  private var initialLocaleIdentifier: String?

  private unowned let storeKitManager: StoreKitManager
  private unowned let network: Network
  private unowned let paywallRequestManager: PaywallRequestManager
  private unowned let paywallManager: PaywallManager
  private unowned let debugManager: DebugManager
  private let factory: RequestFactory & ViewControllerFactory

  init(
    storeKitManager: StoreKitManager,
    network: Network,
    paywallRequestManager: PaywallRequestManager,
    paywallManager: PaywallManager,
    debugManager: DebugManager,
    factory: RequestFactory & ViewControllerFactory
  ) {
    self.storeKitManager = storeKitManager
    self.network = network
    self.paywallRequestManager = paywallRequestManager
    self.paywallManager = paywallManager
    self.debugManager = debugManager
    self.factory = factory
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    initialLocaleIdentifier = Superwall.shared.options.localeIdentifier
    addSubviews()
    Task { await loadPreview() }
    Task { await loadPreviewPaywalls() }
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
    await ensureDevServer()
    await finishLoadingPreview()
  }

  /// Dev mode's local surfaces belong in the debugger however it was opened —
  /// a dashboard preview link should list them too, not just a dev link.
  private func ensureDevServer() async {
    guard
      devServer == nil,
      DevMode.isActive(Superwall.shared.options),
      let location = await DevServerLocator.shared.locate(
        devServerURL: Superwall.shared.options.devServerURL
      )
    else {
      return
    }
    devServer = (base: location.base, surfaces: location.manifest.surfaces)
  }

	func finishLoadingPreview() async {
    if let devSurface = devSurface {
      await loadDevServerPreview(surface: devSurface)
      return
    }

		var paywallId: String?

		if let paywallIdentifier = paywallIdentifier {
			paywallId = paywallIdentifier
		} else if let paywallDatabaseId = paywallDatabaseId {
      // Resolve the numeric database id from the deep link to the paywall's
      // identifier (slug) with a single lookup.
      do {
        let resolution = try await network.resolvePaywallIdentifier(forDatabaseId: paywallDatabaseId)
        paywallId = resolution.identifier
        paywallIdentifier = resolution.identifier
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .debugViewController,
          message: "Failed to Resolve Paywall",
          error: error
        )
        return
      }
    } else {
      return
    }

    do {
      let request = factory.makePaywallRequest(
        placementData: nil,
        responseIdentifiers: .init(paywallId: paywallId),
        overrides: nil,
        isDebuggerLaunched: true,
        presentationSourceType: nil
      )
      var paywall = try await paywallRequestManager.getPaywall(from: request)

      paywall.productVariables = await storeKitManager.getProductVariables(for: paywall)

      self.paywall = paywall
      self.previewPickerButton.setTitle("\(paywall.name)", for: .normal)
      self.activityIndicator.stopAnimating()
      self.addPaywallPreview()
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
    guard let paywall = paywall else {
      return
    }

    let child = factory.makePaywallViewController(
      for: paywall,
      withCache: nil,
      withPaywallArchiveManager: nil,
      delegate: nil
    )
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

  /// Populates the "Your Paywalls" picker from the application in the debugger's
  /// preview token.
  ///
  /// Kicked off from `viewDidLoad` alongside — not after — the preview load, so
  /// the picker is available even when the requested paywall fails to render.
  /// Best-effort: a failure leaves `previewPaywalls` empty and `pressedPreview`
  /// declines to open, which is the behaviour before this was restored.
  private func loadPreviewPaywalls() async {
    do {
      let list = try await network.listPreviewPaywalls()
      previewPaywalls = list.data
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .debugViewController,
        message: "Failed to Load Paywall Picker",
        info: nil,
        error: error
      )
    }
  }

  /// Picks the dev-server surface the debugger opens with, if any.
  func selectDevSurface(id: String?) {
    guard let id = id else {
      return
    }
    devSurface = devServer?.surfaces.first { $0.id == id }
  }

  /// Renders a surface straight from the dev server, synthesised from the
  /// manifest (local URL + the products its `config.ts` declares). Nothing is
  /// fetched from the dashboard, so a paywall that has never been pushed —
  /// or whose app lives in another environment — still previews.
  private func loadDevServerPreview(surface: DevServerSurface) async {
    guard
      let devServer = devServer,
      let location = await DevServerLocator.shared.locate(
        devServerURL: Superwall.shared.options.devServerURL
      ),
      let url = location.manifest.mountURL(for: surface, base: devServer.base)
    else {
      activityIndicator.stopAnimating()
      return
    }

    var paywall = Paywall.devServer(surface: surface, url: url)
    // Product variables are best-effort here: a surface can name products the
    // store has no record of yet, and the preview must still render.
    paywall.productVariables = await storeKitManager.getProductVariables(for: paywall)
    self.paywall = paywall
    paywallIdentifier = paywall.identifier
    paywallDatabaseId = paywall.databaseId
    previewPickerButton.setTitle("\(surface.id) (local)", for: .normal)
    activityIndicator.stopAnimating()
    addPaywallPreview()
  }

  /// The published paywalls to offer. The debugger's preview list needs the
  /// token a dashboard preview link carries; the downloaded config carries the
  /// same paywalls for free, which is what a `superwall dev` link relies on.
  private var publishedPaywalls: [PaywallSummary] {
    if !previewPaywalls.isEmpty {
      return previewPaywalls
    }
    let config = Superwall.shared.dependencyContainer.configManager?.config
    return (config?.paywalls ?? []).map {
      PaywallSummary(id: $0.databaseId, identifier: $0.identifier, name: $0.name)
    }
  }

  /// Whether the picker has anything to offer: local surfaces, a choice of
  /// published paywalls, or no paywall selected yet.
  private var canOpenPicker: Bool {
    if devServer?.surfaces.isEmpty == false {
      return true
    }
    if publishedPaywalls.count > 1 {
      return true
    }
    if paywallDatabaseId == nil {
      return true
    }
    return false
  }

  @objc func pressedPreview() {
    guard canOpenPicker else {
      return
    }
    let devSurfaces = devServer?.surfaces ?? []
    let published = publishedPaywalls

    let picker = DebugPaywallPickerViewController(
      localSurfaceIds: devSurfaces.map { $0.id },
      publishedNames: published.map { $0.name },
      selectedLocalId: devSurface?.id,
      selectedPublishedIndex: published.firstIndex { $0.id == paywallDatabaseId }
    ) { [weak self] kind in
      guard let self = self else {
        return
      }
      switch kind {
      case .local(let index):
        self.devSurface = devSurfaces[index]
      case .published(let index):
        self.devSurface = nil
        self.paywallDatabaseId = published[index].id
        self.paywallIdentifier = published[index].identifier
      }
      Task { await self.loadPreview() }
    }

    let navigationController = UINavigationController(rootViewController: picker)
    navigationController.navigationBar.barStyle = .black
    navigationController.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
    navigationController.modalPresentationStyle = .pageSheet
    #if !os(visionOS)
    if #available(iOS 15.0, *) {
      if let sheet = navigationController.sheetPresentationController {
        sheet.detents = [.medium(), .large()]
        sheet.prefersGrabberVisible = true
      }
    }
    #endif
    present(navigationController, animated: true)
  }

  @objc func pressedExitButton() {
    Task {
      await debugManager.closeDebugger(animated: false)
    }
  }

  @objc func pressedConsoleButton() {
    let releaseVersionNumber = Bundle.main.releaseVersionNumber ?? ""
    let buildVersionNumber = Bundle.main.buildVersionNumber ?? ""
    let localResourceCount = Superwall.shared.options.localResources.count
    presentAlert(
      title: nil,
      message: "Superwall v\(sdkVersion) | App v\(releaseVersionNumber) (\(buildVersionNumber))",
      options: [
        AlertOption(title: "Localization", action: showLocalizationPicker, style: .default),
        AlertOption(title: "Templates", action: showConsole, style: .default),
        AlertOption(
          title: "Local Resources (\(localResourceCount))",
          action: showLocalResources,
          style: .default
        )
      ],
      on: consoleButton
    )
  }

	func showLocalizationPicker() async {
    let viewController = SWLocalizationViewController { [weak self] identifier in
      Superwall.shared.options.localeIdentifier = identifier
      Task { await self?.loadPreview() }
    }

		let navController = UINavigationController(rootViewController: viewController)
		await present(navController, animated: true)
	}

	func showConsole() async {
    guard let paywall = paywall else {
      Logger.debug(
        logLevel: .error,
        scope: .debugViewController,
        message: "Paywall is nil"
      )
      return
    }
    guard let (productsById, _) = try? await storeKitManager.getProducts(
      forPaywall: paywall,
      placement: nil
    ) else {
      return
    }

    var products: [StoreProduct] = []
    for id in paywall.productIds {
      if let product = productsById[id] {
        products.append(product)
      }
    }

    let viewController = SWConsoleViewController(products: products)
    let navController = UINavigationController(rootViewController: viewController)
    navController.modalPresentationStyle = .overFullScreen
    await present(navController, animated: true)
	}

  func showLocalResources() async {
    let viewController = SWLocalResourcesViewController()
    let navController = UINavigationController(rootViewController: viewController)
    await present(navController, animated: true)
  }

  @objc func pressedBottomButton() {
    presentAlert(
      title: nil,
      message: "Which version?",
      options: [
        AlertOption(
          title: "With Intro Offer",
          action: { [weak self] in
            self?.loadAndShowPaywall(introOfferAvailable: true)
          },
          style: .default
        ),
        AlertOption(
          title: "Without Intro Offer",
          action: {  [weak self] in
            self?.loadAndShowPaywall(introOfferAvailable: false)
          },
          style: .default
        )
      ],
      on: bottomButton
    )
  }

  func loadAndShowPaywall(introOfferAvailable: Bool = false) {
    guard let paywallIdentifier = paywallIdentifier else {
      return
    }

    bottomButton.setImage(nil, for: .normal)
    bottomButton.showLoading = true

    let presentationRequest = factory.makePresentationRequest(
      .fromIdentifier(
        paywallIdentifier,
        freeTrialOverride: introOfferAvailable
      ),
      paywallOverrides: nil,
      presenter: self,
      isDebuggerLaunched: true,
      isPaywallPresented: Superwall.shared.isPaywallPresented,
      type: .presentation
    )

    let publisher = PassthroughSubject<PaywallState, Never>()
    cancellable = publisher
      .receive(on: DispatchQueue.main)
      .sink { state in
        switch state {
        case .presented:
          self.bottomButton.showLoading = false

          let playButton = UIImage(named: "SuperwallKit_play_button", in: Bundle.module, compatibleWith: nil)!
          self.bottomButton.setImage(
            playButton,
            for: .normal
          )
        case .skipped(let reason):
          var errorMessage: String?

          switch reason {
          case .holdout:
            errorMessage = "The user was assigned to a holdout."
          case .noAudienceMatch:
            errorMessage = "The user didn't match an audience."
          case .placementNotFound:
            errorMessage = "Couldn't find placement."
          }
          self.presentAlert(
            title: "Paywall Skipped",
            message: errorMessage,
            on: self.view
          )
          self.bottomButton.showLoading = false

          let playButton = UIImage(named: "SuperwallKit_play_button", in: Bundle.module, compatibleWith: nil)!
          self.bottomButton.setImage(playButton, for: .normal)
          self.activityIndicator.stopAnimating()
        case .dismissed,
          .willDismiss:
          break
        case .presentationError(let error):
          Logger.debug(
            logLevel: .error,
            scope: .debugViewController,
            message: "Failed to Show Paywall",
            info: nil
          )
          self.presentAlert(
            title: "Presentation Error",
            message: error.safeLocalizedDescription,
            on: self.view
          )
          self.bottomButton.showLoading = false

          let playButton = UIImage(named: "SuperwallKit_play_button", in: Bundle.module, compatibleWith: nil)!
          self.bottomButton.setImage(playButton, for: .normal)
          self.activityIndicator.stopAnimating()
        }
      }

    Task {
      await Superwall.shared.internallyPresent(presentationRequest, publisher)
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    paywallManager.resetCache()
    debugManager.isDebuggerLaunched = false
    Superwall.shared.options.localeIdentifier = initialLocaleIdentifier
  }
}

extension DebugViewController {
  func presentAlert(
    title: String?,
    message: String?,
    options: [AlertOption] = [],
    on sourceView: UIView
  ) {
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

    for option in options {
      let action = UIAlertAction(
        title: option.title,
        style: option.style
      ) { _ in
        Task {
          await option.action?()
        }
      }
      alertController.addAction(action)
    }

    alertController.popoverPresentationController?.sourceView = sourceView
    alertController.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
    alertController.view.tintColor = .black

    present(
      alertController,
      animated: true
    )
  }
}
