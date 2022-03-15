//
//  File.swift
//  
//
//  Created by brian on 7/21/21.
//

import WebKit
import UIKit
import Foundation
import SafariServices

protocol SWPaywallViewControllerDelegate: AnyObject {
	func eventDidOccur(
    paywallViewController: SWPaywallViewController,
    result: PaywallPresentationResult
  )
}

enum PaywallLoadingState {
  case unknown
  case loadingPurchase
  case loadingResponse
  case ready
}

typealias PaywallDismissalCompletionBlock = (PaywallDismissalResult) -> Void

// swiftlint:disable:next type_body_length
final class SWPaywallViewController: UIViewController {
  // MARK: - Properties
	weak var delegate: SWPaywallViewControllerDelegate?
	var dismissalCompletion: PaywallDismissalCompletionBlock?
	var isPresented = false
	var calledDismiss = false
  var paywallResponse: PaywallResponse?
	var eventData: EventData?
  var calledByIdentifier = false
	var readyForEventTracking = false
	var showRefreshTimer: Timer?
	var isSafariVCPresented = false

	var isActive: Bool {
		return isPresented || isBeingPresented
	}
  var isPresentedViewController: Bool {
    self == PaywallManager.shared.presentedViewController
  }

  // Views
	lazy var shimmerView = ShimmeringView(frame: self.view.bounds)
  private lazy var eventHandler = WebEventHandler(delegate: self)
  lazy var webView = SWWebView(delegate: eventHandler)

	var paywallInfo: PaywallInfo? {
		return paywallResponse?.getPaywallInfo(
      fromEvent: eventData,
      calledByIdentifier: calledByIdentifier,
      includeExperiment: true
    )
	}

  var presentationStyle: PaywallPresentationStyle {
    return paywallResponse?.presentationStyle ?? .sheet
  }

  private var purchaseLoadingIndicatorContainer: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isUserInteractionEnabled = false
    view.clipsToBounds = false
    return view
  }()

  private var purchaseLoadingIndicator: UIActivityIndicatorView = {
    let spinner = UIActivityIndicatorView()
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.style = .whiteLarge
    spinner.hidesWhenStopped = false
    spinner.alpha = 0.0
    spinner.startAnimating()
    return spinner
  }()

  var loadingState: PaywallLoadingState  = .unknown {
    didSet {
      loadingStateDidChange(from: oldValue)
    }
  }

	lazy var refreshPaywallButton: UIButton = {
    UIComponentFactory.makeButton(
      imageNamed: "reload_paywall",
      target: self,
      action: #selector(pressedRefreshPaywall)
    )
	}()

	lazy var exitButton: UIButton = {
    UIComponentFactory.makeButton(
      imageNamed: "exit_paywall",
      target: self,
      action: #selector(pressedExitPaywall)
    )
	}()

	var contentPlaceholderImageView: UIImageView = {
    // swiftlint:disable:next force_unwrapping
    let placeholder = UIImage(named: "paywall_placeholder", in: Bundle.module, compatibleWith: nil)!
		let imageView = UIImageView(image: placeholder)
		imageView.contentMode = .scaleAspectFit
		imageView.tintColor = .white
		imageView.backgroundColor = .clear
		imageView.clipsToBounds = true
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.isHidden = false
		imageView.alpha = 1.0 - 0.618
		return imageView
	}()


	// MARK: - View Lifecycle

	init(
    paywallResponse: PaywallResponse?,
    delegate: SWPaywallViewControllerDelegate? = nil
  ) {
		self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
		if let paywallResponse = paywallResponse {
			setPaywallResponse(paywallResponse)
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  override func viewDidLoad() {
    super.viewDidLoad()
		addObservers()
		layoutSubviews()
	}

  private func addObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  private func layoutSubviews() {
    shimmerView.isShimmering = true
    view.addSubview(shimmerView)
    view.addSubview(purchaseLoadingIndicatorContainer)
    purchaseLoadingIndicatorContainer.addSubview(purchaseLoadingIndicator)
    view.addSubview(webView)
    shimmerView.translatesAutoresizingMaskIntoConstraints = false
    shimmerView.contentView = contentPlaceholderImageView

    view.addSubview(refreshPaywallButton)
    view.addSubview(exitButton)

    NSLayoutConstraint.activate([
      purchaseLoadingIndicatorContainer.topAnchor.constraint(equalTo: view.topAnchor),
      purchaseLoadingIndicatorContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      purchaseLoadingIndicatorContainer.widthAnchor.constraint(equalTo: view.widthAnchor),
      purchaseLoadingIndicatorContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),

      purchaseLoadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      purchaseLoadingIndicator.centerYAnchor.constraint(equalTo: purchaseLoadingIndicatorContainer.bottomAnchor),

      shimmerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      shimmerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      shimmerView.topAnchor.constraint(equalTo: view.topAnchor),
      shimmerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.topAnchor.constraint(equalTo: view.topAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),

      refreshPaywallButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 17),
      refreshPaywallButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: 0),
      refreshPaywallButton.widthAnchor.constraint(equalToConstant: 55),
      refreshPaywallButton.heightAnchor.constraint(equalToConstant: 55),

      exitButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 17),
      exitButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 0),
      exitButton.widthAnchor.constraint(equalToConstant: 55),
      exitButton.heightAnchor.constraint(equalToConstant: 55)
    ])
  }

  override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

    guard isActive else {
      return
    }
    if isSafariVCPresented {
      return
    }

    if #available(iOS 15.0, *),
      !DeviceHelper.shared.isMac {
//       webView.setAllMediaPlaybackSuspended(false) // ignore-xcode-12
    }

    if UIWindow.isLandscape {
      let placeholder = UIImage(
        named: "paywall_placeholder_landscape",
        in: Bundle.module,
        compatibleWith: nil
      )!
      // swiftlint:disable:previous force_unwrapping
      contentPlaceholderImageView.image = placeholder
    }

    // if the loading state is ready, re template user attributes
    if self.loadingState == .ready {
      eventHandler.handleEvent(.templateParamsAndUserAttributes)
    }
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if isPresented,
      !isSafariVCPresented,
      !calledDismiss {
				Paywall.delegate?.willDismissPaywall?()
		}
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

    guard isPresented else {
      return
    }
    if isSafariVCPresented {
      return
    }
    if readyForEventTracking {
      trackClose()
    }
    if #available(iOS 15.0, *),
      !DeviceHelper.shared.isMac {
//       webView.setAllMediaPlaybackSuspended(true) // ignore-xcode-12
    }

    if !calledDismiss {
      didDismiss(
        .withResult(
          paywallInfo: paywallInfo,
          state: .closed
        )
      )
    }

    calledDismiss = false
	}

	func loadingStateDidChange(from oldValue: PaywallLoadingState) {
		onMain { [weak self] in
			guard let loadingState = self?.loadingState else {
        return
      }

			switch loadingState {
			case .unknown:
				break
			case .loadingPurchase:
				self?.shimmerView.isShimmering = false
				self?.showRefreshButtonAfterTimeout(show: true)
				self?.shimmerView.alpha = 0.0
				self?.shimmerView.transform = .identity
				self?.purchaseLoadingIndicator.alpha = 0.0
				self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
        UIView.springAnimate {
          self?.webView.alpha = 0.0
          self?.webView.transform = CGAffineTransform.identity.scaledBy(x: 0.97, y: 0.97)
          self?.purchaseLoadingIndicator.alpha = 1.0
          self?.purchaseLoadingIndicator.transform = .identity
        }
			case .loadingResponse:
				self?.shimmerView.isShimmering = true
				self?.shimmerView.alpha = 0.0
				self?.shimmerView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
				self?.showRefreshButtonAfterTimeout(show: true)
        UIView.springAnimate {
          self?.webView.alpha = 0.0
          self?.shimmerView.alpha = 1.0
          self?.webView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -10)// .scaledBy(x: 0.97, y: 0.97)
          self?.shimmerView.transform = .identity
          self?.purchaseLoadingIndicator.alpha = 0.0
          self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
        }
			case .ready:
        let translation = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
        let scaling = CGAffineTransform.identity.scaledBy(x: 0.97, y: 0.97)
				self?.webView.transform = oldValue == .loadingPurchase ? scaling : translation
				self?.showRefreshButtonAfterTimeout(show: false)
        UIView.springAnimate(
          withDuration: 1,
          delay: 0.25,
          animations: {
            self?.webView.alpha = 1.0
            self?.webView.transform = .identity
            self?.shimmerView.alpha = 0.0
            self?.purchaseLoadingIndicator.alpha = 0.0
            self?.purchaseLoadingIndicator.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
          },
          completion: { _ in
            self?.shimmerView.isShimmering = false
          }
        )
			}
		}
	}

	func showRefreshButtonAfterTimeout(show: Bool) {
		showRefreshTimer?.invalidate()
		showRefreshTimer = nil

		if show {
      showRefreshTimer = Timer.scheduledTimer(
        withTimeInterval: 4.0,
        repeats: false
      ) { [weak self] _ in
        self?.refreshPaywallButton.isHidden = false
        self?.refreshPaywallButton.alpha = 0.0
        self?.exitButton.isHidden = false
        self?.exitButton.alpha = 0.0
        UIView.springAnimate(withDuration: 2) {
          self?.refreshPaywallButton.alpha = 1.0
          self?.exitButton.alpha = 1.0
        }
      }
		} else {
			hideRefreshButton()
			return
		}
	}

	func hideRefreshButton() {
		showRefreshTimer?.invalidate()
		showRefreshTimer = nil
    UIView.springAnimate(
      animations: {
        self.refreshPaywallButton.alpha = 0.0
        self.exitButton.alpha = 0.0
      },
      completion: { _ in
        self.refreshPaywallButton.isHidden = true
        self.exitButton.isHidden = true
      }
    )
	}

	@objc func pressedRefreshPaywall() {
    dismiss(
      .withResult(
        paywallInfo: nil,
        state: .closed
      ),
      shouldCallCompletion: false
    ) {
      Paywall.presentAgain()
    }
	}

	@objc func pressedExitPaywall() {
    dismiss(
      .withResult(
        paywallInfo: nil,
        state: .closed
      ),
      shouldCallCompletion: true
    ) {
      PaywallManager.shared.removePaywall(withViewController: self)
    }
	}

	func setPaywallResponse(_ paywallResponse: PaywallResponse) {
    self.paywallResponse = paywallResponse

    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }

      self.webView.alpha = 0.0
      self.view.backgroundColor = paywallResponse.paywallBackgroundColor
      let loadingColor = paywallResponse.paywallBackgroundColor.readableOverlayColor
      self.purchaseLoadingIndicator.color = loadingColor
      self.refreshPaywallButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
      self.exitButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
      self.contentPlaceholderImageView.tintColor = loadingColor.withAlphaComponent(0.5)

      if let urlString = self.paywallResponse?.url,
        let url = URL(string: urlString) {
        if let paywallInfo = self.paywallInfo {
          Paywall.track(.paywallWebviewLoadStart(paywallInfo: paywallInfo))
        }

        self.webView.load(URLRequest(url: url))
        if self.paywallResponse?.webViewLoadStartTime == nil,
          self.paywallResponse != nil {
          self.paywallResponse?.webViewLoadStartTime = Date()
        }
        self.loadingState = .loadingResponse
      }
    }

    switch presentationStyle {
    case .sheet:
      modalPresentationStyle = .formSheet
    case .modal:
      modalPresentationStyle = .formSheet
    case .fullscreen:
      modalPresentationStyle = .overFullScreen
    }
  }

	func set(
    eventData: EventData?,
    calledFromIdentifier: Bool,
    dismissalBlock: PaywallDismissalCompletionBlock?
  ) {
		self.eventData = eventData
		self.calledByIdentifier = calledFromIdentifier
		self.dismissalCompletion = dismissalBlock
	}

	func trackOpen() {
		if let i = paywallInfo {
			Paywall.track(.paywallOpen(paywallInfo: i))
		}
	}

	func trackClose() {
		if let i = paywallInfo {
			Paywall.track(.paywallClose(paywallInfo: i))
		}
	}

	func presentAlert(
    title: String? = nil,
    message: String? = nil,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil,
    closeActionTitle: String = "Done"
  ) {
    guard presentedViewController == nil else {
      return
    }
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

    if let actionTitle = actionTitle {
      let alertAction = UIAlertAction(title: actionTitle, style: .default) { _ in
        action?()
      }
      alertController.addAction(alertAction)
    }

    let action = UIAlertAction(title: closeActionTitle, style: .cancel)
    alertController.addAction(action)

    present(alertController, animated: true) { [weak self] in
      if let loadingState = self?.loadingState,
        loadingState != .loadingResponse {
        self?.loadingState = .ready
      }
    }
  }

  @objc func applicationWillResignActive(_ sender: AnyObject? = nil) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.loadingState == .loadingPurchase {
        UIView.springAnimate {
          let height = self.purchaseLoadingIndicatorContainer.frame.size.height
          let transform = CGAffineTransform.identity.translatedBy(
            x: 0,
            y: height * 0.5 * -1
          )
          self.purchaseLoadingIndicatorContainer.transform = transform
        }
      }
    }
  }

  @objc func applicationDidBecomeActive(_ sender: AnyObject? = nil) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      guard self.loadingState == .loadingPurchase else {
        return
      }
      UIView.springAnimate {
        self.purchaseLoadingIndicatorContainer.transform = .identity
      }
    }
  }
}

// MARK: - WebEventHandlerDelegate
extension SWPaywallViewController: WebEventHandlerDelegate {
  func eventDidOccur(_ paywallPresentationResult: PaywallPresentationResult) {
    self.delegate?.eventDidOccur(
      paywallViewController: self,
      result: paywallPresentationResult
    )
  }

  func presentSafari(_ url: URL) {
    let safariVC = SFSafariViewController(url: url)
    safariVC.delegate = self
    self.isSafariVCPresented = true
    present(safariVC, animated: true)
  }
}

// presentation logic
extension SWPaywallViewController {
	func present(
    on presenter: UIViewController,
    fromEventData: EventData?,
    calledFromIdentifier: Bool,
    dismissalBlock: PaywallDismissalCompletionBlock?,
    completion: @escaping (Bool) -> Void
  ) {
		if Paywall.shared.isPaywallPresented || presenter is SWPaywallViewController || isBeingPresented {
			completion(false)
			return
		} else {
			prepareForPresentation()
			set(eventData: fromEventData, calledFromIdentifier: calledFromIdentifier, dismissalBlock: dismissalBlock)
      presenter.present(
        self,
        animated: Paywall.shouldAnimatePaywallPresentation
      ) { [weak self] in
        self?.isPresented = true
        self?.presentationDidFinish()
        completion(true)
      }
		}
	}

	func dismiss(
    _ dismissalResult: PaywallDismissalResult,
    shouldCallCompletion: Bool = true,
    completion: (() -> Void)? = nil
  ) {
		calledDismiss = true
		Paywall.delegate?.willDismissPaywall?()
		dismiss(animated: Paywall.shouldAnimatePaywallDismissal) { [weak self] in
      self?.didDismiss(
        dismissalResult,
        shouldCallCompletion: shouldCallCompletion,
        completion: completion
      )
		}
	}

	func didDismiss(
    _ dismissalResult: PaywallDismissalResult,
    shouldCallCompletion: Bool = true,
    completion: (() -> Void)? = nil
  ) {
		isPresented = false
		if Paywall.isGameControllerEnabled && GameControllerManager.shared.delegate == self {
			GameControllerManager.shared.delegate = nil
		}
		Paywall.delegate?.didDismissPaywall?()
    //  loadingState = .ready
		if shouldCallCompletion {
			dismissalCompletion?(dismissalResult)
		}
		completion?()
		Paywall.shared.destroyPresentingWindow()
	}

	func prepareForPresentation() {
		readyForEventTracking = false
		willMove(toParent: nil)
		view.removeFromSuperview()
		removeFromParent()
		view.alpha = 1.0
		view.transform = .identity
		webView.scrollView.contentOffset = CGPoint.zero

		Paywall.delegate?.willPresentPaywall?()
		Paywall.shared.paywallWasPresentedThisSession = true
		Paywall.shared.recentlyPresented = true
	}

	func presentationDidFinish() {
		Paywall.delegate?.didPresentPaywall?()
		readyForEventTracking = true
		trackOpen()

		if Paywall.isGameControllerEnabled {
			GameControllerManager.shared.delegate = self
		}

		if Paywall.delegate == nil {
			presentAlert(
        title: "Almost Done...",
        message: "Set Paywall.delegate to handle purchases, restores and more!",
        actionTitle: "Docs →",
        action: {
          if let url = URL(string: "https://docs.superwall.me/docs/configuring-the-sdk-1") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
          }
        },
        closeActionTitle: "Done"
      )
		}
	}
}

// MARK: - SFSafariViewControllerDelegate
extension SWPaywallViewController: SFSafariViewControllerDelegate {
	func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
		self.isSafariVCPresented = false
	}
}

// MARK: - GameControllerDelegate
extension SWPaywallViewController: GameControllerDelegate {
  func connectionStatusDidChange(isConnected: Bool) {
    Logger.debug(
      logLevel: .debug,
      scope: .gameControllerManager,
      message: "Status Changed",
      info: ["connected": isConnected],
      error: nil
    )
  }

  func gameControllerEventDidOccur(event: GameControllerEvent) {
    if let payload = event.jsonString {
      let script = "window.paywall.accept([\(payload)])"
      webView.evaluateJavaScript(script, completionHandler: nil)
      Logger.debug(
        logLevel: .debug,
        scope: .gameControllerManager,
        message: "Received Event",
        info: ["payload": payload],
        error: nil
      )
    }
  }
}

// MARK: - Stubbable
extension SWPaywallViewController: Stubbable {
  static func stub() -> SWPaywallViewController {
    return SWPaywallViewController(
      paywallResponse: nil,
      delegate: nil
    )
  }
  // swiftlint:disable:next file_length
}
