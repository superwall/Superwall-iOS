//
//  File.swift
//  
//
//  Created by brian on 7/21/21.
//
// swiftlint:disable file_length
// swiftlint:disable trailing_closure

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
final class SWPaywallViewController: UIViewController, SWWebViewDelegate {
  // MARK: - Properties
	weak var delegate: SWPaywallViewControllerDelegate?
	var dismissalCompletion: PaywallDismissalCompletionBlock?
	var isPresented = false
	var calledDismiss = false
  var paywallResponse: PaywallResponse
  var presentationInfo: PresentationInfo?
  var calledByIdentifier = false
	var readyForEventTracking = false
	var showRefreshTimer: Timer?
	var isSafariVCPresented = false
  var presentationStyle: PaywallPresentationStyle
  var presentationIsAnimated: Bool {
    if presentationStyle == .fullscreenNoAnimation {
      return false
    } else {
      return Paywall.shouldAnimatePaywallPresentation
    }
  }
  static var cache = Set<SWPaywallViewController>()

	var isActive: Bool {
		return isPresented || isBeingPresented
	}
  var isPresentedViewController: Bool {
    self == PaywallManager.shared.presentedViewController
  }

  // Views
  lazy var webView = SWWebView(delegate: self)

	var paywallInfo: PaywallInfo {
		return paywallResponse.getPaywallInfo(
      fromEvent: presentationInfo?.eventData,
      calledByIdentifier: calledByIdentifier
    )
	}
  private var purchaseLoader = SWPaywallLoadingView()
  private var shimmerView: ShimmerView?

  var loadingState: PaywallLoadingState = .unknown {
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

  var cacheKey: String

  private var hasRefreshAlertController = false
  lazy var refreshAlertViewController: UIAlertController = {
    hasRefreshAlertController = true
    let alertController = UIAlertController(
      title: "Waiting to Purchase...",
      message: "Your connection may be offline. Waiting for transaction to begin.",
      preferredStyle: .alert
    )

    let refreshAction = UIAlertAction(title: "Refresh", style: .default) { [weak self] _ in
      self?.pressedRefreshPaywall()
    }
    alertController.addAction(refreshAction)

    let closeAction = UIAlertAction(title: "Exit", style: .destructive) { [weak self] _ in
      self?.pressedExitPaywall()
    }
    alertController.addAction(closeAction)

    return alertController
  }()


	// MARK: - View Lifecycle

	init(
    paywallResponse: PaywallResponse,
    delegate: SWPaywallViewControllerDelegate? = nil
  ) {
    self.cacheKey = PaywallCacheLogic.key(forIdentifier: paywallResponse.identifier)
		self.delegate = delegate
    self.paywallResponse = paywallResponse
    presentationStyle = paywallResponse.presentationStyleV2
    super.init(nibName: nil, bundle: nil)
    configureUI()
    loadPaywallWebpage()
    SWPaywallViewController.cache.insert(self)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

  deinit {
    SWPaywallViewController.cache.remove(self)
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
    view.addSubview(purchaseLoader)
    view.addSubview(webView)

    view.addSubview(refreshPaywallButton)
    view.addSubview(exitButton)

    NSLayoutConstraint.activate([
      purchaseLoader.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      purchaseLoader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      purchaseLoader.widthAnchor.constraint(equalTo: view.widthAnchor),
      purchaseLoader.heightAnchor.constraint(equalTo: view.heightAnchor),

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
      webView.setAllMediaPlaybackSuspended(false) // ignore-xcode-12
    }

    // if the loading state is ready, re template user attributes
    if loadingState == .ready {
      webView.eventHandler.handleEvent(.templateParamsAndUserAttributes)
    }
	}

  override var preferredStatusBarStyle: UIStatusBarStyle {
    if let isDark = view.backgroundColor?.isDarkColor, isDark {
      return .lightContent
    }

    if #available(iOS 13.0, *) {
      return .darkContent
    } else {
      return .default
    }
  }

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
    guard isPresented else {
      return
    }
    if isSafariVCPresented {
      return
    }
    if calledDismiss {
      return
    }
    Paywall.delegate?.willDismissPaywall?()
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
      webView.setAllMediaPlaybackSuspended(true) // ignore-xcode-12
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
			guard
        let self = self,
        self.loadingState != oldValue
      else {
        return
      }

      switch self.loadingState {
      case .unknown:
				break
      case .loadingPurchase:
				self.showRefreshButtonAfterTimeout(true, useModal: true)
        self.purchaseLoader.toggle(show: true, animated: true)
      case .loadingResponse:
        self.addShimmerView()
				self.showRefreshButtonAfterTimeout(true)
        self.purchaseLoader.toggle(show: false, animated: false)
        UIView.springAnimate {
          self.webView.alpha = 0.0
          self.webView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -10)
        }
      case .ready:
        let translation = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
        self.webView.transform = oldValue == .loadingPurchase ? .identity : translation
				self.showRefreshButtonAfterTimeout(false)
        self.purchaseLoader.toggle(show: false, animated: true)

        if oldValue != .loadingPurchase {
          UIView.springAnimate(
            withDuration: 1,
            delay: 0.25,
            animations: {
              self.shimmerView?.alpha = 0.0
              self.webView.alpha = 1.0
              self.webView.transform = .identity
            },
            completion: { _ in
              self.shimmerView?.removeFromSuperview()
              self.shimmerView = nil
            }
          )
        }
			}
		}
	}

  var presentedModel = false

  private func refreshAlert(show: Bool) {
    if show {
      present(refreshAlertViewController, animated: true)
    } else {
      guard hasRefreshAlertController else {
        return
      }
      refreshAlertViewController.dismiss(animated: true)
    }
  }

  func showRefreshButtonAfterTimeout(_ isVisible: Bool, useModal: Bool = false) {
		showRefreshTimer?.invalidate()
		showRefreshTimer = nil

		if isVisible {
      showRefreshTimer = Timer.scheduledTimer(
        withTimeInterval: 5.0,
        repeats: false
      ) { [weak self] _ in
        guard let self = self else {
          return
        }

        if useModal {
          self.refreshAlert(show: true)
          return
        }

        self.view.bringSubviewToFront(self.refreshPaywallButton)
        self.view.bringSubviewToFront(self.exitButton)

        self.refreshPaywallButton.isHidden = false
        self.refreshPaywallButton.alpha = 0.0
        self.exitButton.isHidden = false
        self.exitButton.alpha = 0.0

        let trackedEvent = SuperwallEvent.PaywallWebviewLoad(
          state: .timeout,
          paywallInfo: self.paywallInfo
        )
        Paywall.track(trackedEvent)

        UIView.springAnimate(withDuration: 2) {
          self.refreshPaywallButton.alpha = 1.0
          self.exitButton.alpha = 1.0
        }
      }
		} else {
      refreshAlert(show: false)
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
        paywallInfo: paywallInfo,
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
        paywallInfo: paywallInfo,
        state: .closed
      ),
      shouldCallCompletion: true
    ) {
      PaywallManager.shared.removePaywall(withViewController: self)
    }
	}

	private func configureUI() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      self.webView.alpha = 0.0
      self.view.backgroundColor = self.paywallResponse.paywallBackgroundColor
      let loadingColor = self.paywallResponse.paywallBackgroundColor.readableOverlayColor
      self.purchaseLoader.paywallBackgroundColor = self.paywallResponse.paywallBackgroundColor
      self.refreshPaywallButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
      self.exitButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
      self.modalPresentationCapturesStatusBarAppearance = true
      self.setNeedsStatusBarAppearanceUpdate()
    }
  }


  private func loadPaywallWebpage() {
    let urlString = paywallResponse.url
    guard let url = URL(string: urlString) else {
      return
    }

    let trackedEvent = SuperwallEvent.PaywallWebviewLoad(
      state: .start,
      paywallInfo: paywallInfo
    )
    Paywall.track(trackedEvent)

    if Paywall.options.useCachedPaywallTemplates {
      let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
      webView.load(request)
    } else {
      let request = URLRequest(url: url)
      webView.load(request)
    }

    if paywallResponse.webViewLoadStartTime == nil {
      paywallResponse.webViewLoadStartTime = Date()
    }

    SessionEventsManager.shared.triggerSession.trackWebviewLoad(
      forPaywallId: paywallInfo.id,
      state: .start
    )

    loadingState = .loadingResponse
  }

	func set(
    _ presentationInfo: PresentationInfo,
    dismissalBlock: PaywallDismissalCompletionBlock?
  ) {
		self.presentationInfo = presentationInfo
		self.dismissalCompletion = dismissalBlock
	}

	func trackOpen() {
    SessionEventsManager.shared.triggerSession.trackPaywallOpen()
    Storage.shared.saveLastPaywallView()
    Storage.shared.incrementTotalPaywallViews()
    let trackedEvent = SuperwallEvent.PaywallOpen(paywallInfo: paywallInfo)
    Paywall.track(trackedEvent)
	}

	func trackClose() {
    SessionEventsManager.shared.triggerSession.trackPaywallClose()

    let trackedEvent = SuperwallEvent.PaywallClose(paywallInfo: paywallInfo)
    Paywall.track(trackedEvent)
	}

	func presentAlert(
    title: String? = nil,
    message: String? = nil,
    actionTitle: String? = nil,
    closeActionTitle: String = "Done",
    action: (() -> Void)? = nil,
    onCancel: (() -> Void)? = nil
  ) {
    guard presentedViewController == nil else {
      return
    }
    let alertController = UIAlertController(
      title: title,
      message: message,
      preferredStyle: .alert
    )

    if let actionTitle = actionTitle {
      let alertAction = UIAlertAction(
        title: actionTitle,
        style: .default
      ) { _ in
        action?()
      }
      alertController.addAction(alertAction)
    }

    let action = UIAlertAction(
      title: closeActionTitle,
      style: .cancel
    ) { _ in
      onCancel?()
    }
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
        self.purchaseLoader.move(up: true)
      }
    }
  }

  @objc func applicationDidBecomeActive(_ sender: AnyObject? = nil) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.loadingState == .loadingPurchase {
        self.purchaseLoader.move(up: false)
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

  func presentSafariInApp(_ url: URL) {
    let safariVC = SFSafariViewController(url: url)
    safariVC.delegate = self
    self.isSafariVCPresented = true
    present(safariVC, animated: true)
  }

  func presentSafariExternal(_ url: URL) {
    UIApplication.shared.open(url)
  }

  func openDeepLink(_ url: URL) {
    dismiss(
      .withResult(
        paywallInfo: paywallInfo,
        state: .closed
      ),
      shouldCallCompletion: true
    ) { [weak self] in
      self?.eventDidOccur(.openedDeepLink(url: url))
      UIApplication.shared.open(url)
    }
  }
}

// MARK: - presentation logic
extension SWPaywallViewController {
	func present(
    on presenter: UIViewController,
    presentationInfo: PresentationInfo,
    presentationStyleOverride: PaywallPresentationStyle?,
    dismissalBlock: PaywallDismissalCompletionBlock?,
    completion: @escaping (Bool) -> Void
  ) {
		if Paywall.shared.isPaywallPresented || presenter is SWPaywallViewController || isBeingPresented {
			completion(false)
			return
		} else {
      addShimmerView(onPresent: true)
			prepareForPresentation()
      set(presentationInfo, dismissalBlock: dismissalBlock)
      setPresentationStyle(withOverride: presentationStyleOverride)

      presenter.present(
        self,
        animated: presentationIsAnimated
      ) { [weak self] in
        self?.isPresented = true
        self?.presentationDidFinish()
        completion(true)
      }
		}
	}

  private func addShimmerView(onPresent: Bool = false) {
    guard shimmerView == nil else {
      return
    }
    guard loadingState == .loadingResponse || loadingState == .unknown else {
      return
    }
    guard isActive || onPresent else {
      return
    }
    let shimmerView = ShimmerView(
      backgroundColor: paywallResponse.paywallBackgroundColor,
      tintColor: paywallResponse.paywallBackgroundColor.readableOverlayColor,
      isLightBackground: !paywallResponse.paywallBackgroundColor.isDarkColor
    )
    view.addSubview(shimmerView)
    NSLayoutConstraint.activate([
      shimmerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      shimmerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      shimmerView.topAnchor.constraint(equalTo: view.topAnchor),
      shimmerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    self.shimmerView = shimmerView
  }

	func dismiss(
    _ dismissalResult: PaywallDismissalResult,
    shouldCallCompletion: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    prepareToDismiss(withInfo: dismissalResult.paywallInfo)

		dismiss(animated: presentationIsAnimated) { [weak self] in
      self?.didDismiss(
        dismissalResult,
        shouldCallCompletion: shouldCallCompletion,
        completion: completion
      )
		}
	}

  private func prepareToDismiss(withInfo paywallInfo: PaywallInfo?) {
    calledDismiss = true
    Paywall.shared.latestDismissedPaywallInfo = paywallInfo
    Paywall.delegate?.willDismissPaywall?()
  }

  private func setPresentationStyle(withOverride presentationStyleOverride: PaywallPresentationStyle?) {
    presentationStyle = presentationStyleOverride ?? paywallResponse.presentationStyleV2

    switch presentationStyle {
    case .modal:
      modalPresentationStyle = .pageSheet
    case .fullscreen:
      modalPresentationStyle = .overFullScreen
    case .push:
      modalPresentationStyle = .custom
      transitioningDelegate = self
    case .fullscreenNoAnimation:
      modalPresentationStyle = .overFullScreen
    case .none:
      break
    }
  }

	func didDismiss(
    _ dismissalResult: PaywallDismissalResult,
    shouldCallCompletion: Bool = true,
    completion: (() -> Void)? = nil
  ) {
		isPresented = false
    if Paywall.options.isGameControllerEnabled && GameControllerManager.shared.delegate == self {
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

    if Paywall.options.isGameControllerEnabled {
			GameControllerManager.shared.delegate = self
		}

		if Paywall.delegate == nil {
			presentAlert(
        title: "Almost Done...",
        message: "Set Paywall.delegate to handle purchases, restores and more!",
        actionTitle: "Docs →",
        closeActionTitle: "Done",
        onCancel: {
          if let url = URL(string: "https://docs.superwall.com/docs/configuring-the-sdk#conforming-to-the-delegate") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
          }
        }
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
      paywallResponse: .stub(),
      delegate: nil
    )
  }
}

// MARK: - UIViewControllerTransitioningDelegate
extension SWPaywallViewController: UIViewControllerTransitioningDelegate {
  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return PushTransition(state: .presenting)
  }

  func animationController(
    forDismissed dismissed: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return PushTransition(state: .dismissing)
  }
}
