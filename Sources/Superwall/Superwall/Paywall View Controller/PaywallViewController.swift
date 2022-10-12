//
//  File.swift
//  
//
//  Created by brian on 7/21/21.
//
// swiftlint:disable file_length trailing_closure implicitly_unwrapped_optional type_body_length

import WebKit
import UIKit
import Foundation
import SafariServices
import Combine

protocol SWPaywallViewControllerDelegate: AnyObject {
	@MainActor func eventDidOccur(
    paywallViewController: PaywallViewController,
    result: PaywallPresentationResult
  ) async
}

enum PaywallLoadingState {
  case unknown
  case loadingPurchase
  case loadingResponse
  case ready
}

final class PaywallViewController: UIViewController, SWWebViewDelegate, LoadingDelegate {
  // MARK: - Internal Properties
  override var preferredStatusBarStyle: UIStatusBarStyle {
    if let isDark = view.backgroundColor?.isDarkColor, isDark {
      return .lightContent
    }
    return .darkContent
  }
  var paywall: Paywall
  var eventData: EventData?
  var cacheKey: String
  var isActive: Bool {
    return isPresented || isBeingPresented
  }
  var isPresentedViewController: Bool {
    self == PaywallManager.shared.presentedViewController
  }

  lazy var webView = SWWebView(delegate: self)

  var paywallInfo: PaywallInfo {
    return paywall.getInfo(
      fromEvent: eventData,
      calledByIdentifier: calledByIdentifier
    )
  }
  var loadingState: PaywallLoadingState = .unknown {
    didSet {
      loadingStateDidChange(from: oldValue)
    }
  }
  static var cache = Set<PaywallViewController>()

  // MARK: - Private Properties
  private weak var delegate: SWPaywallViewControllerDelegate?
  private var paywallStatePublisher: PassthroughSubject<PaywallState, Never>!
  private var presentationPublisher: PresentationSubject!
  private var isPresented = false
  private var calledDismiss = false
  private var calledByIdentifier = false
  private var readyForEventTracking = false
	private var showRefreshTimer: Timer?
	private var isSafariVCPresented = false
  private var presentationStyle: PaywallPresentationStyle
  private var presentationIsAnimated: Bool {
    return presentationStyle != .fullscreenNoAnimation
  }

  private var loadingViewController: LoadingViewController?
  private var shimmerView: ShimmerView?
  private lazy var refreshPaywallButton: UIButton = {
    UIComponentFactory.makeButton(
      imageNamed: "reload_paywall",
      target: self,
      action: #selector(pressedRefreshPaywall)
    )
	}()
  private lazy var exitButton: UIButton = {
    UIComponentFactory.makeButton(
      imageNamed: "exit_paywall",
      target: self,
      action: #selector(pressedExitPaywall)
    )
  }()
  private var hasRefreshAlertController = false
  private lazy var refreshAlertViewController: UIAlertController = {
    hasRefreshAlertController = true
    return AlertControllerFactory.create(
      title: "Waiting to Purchase...",
      message: "Your connection may be offline. Waiting for transaction to begin.",
      actionTitle: "Refresh",
      closeActionTitle: "Exit",
      closeActionStyle: .destructive,
      action: { [weak self] in
        self?.pressedRefreshPaywall()
      },
      onClose: { [weak self] in
        self?.pressedExitPaywall()
      }
    )
  }()

	// MARK: - View Lifecycle

	init(
    paywall: Paywall,
    delegate: SWPaywallViewControllerDelegate? = nil
  ) {
    self.cacheKey = PaywallCacheLogic.key(forIdentifier: paywall.identifier)
		self.delegate = delegate
    self.paywall = paywall
    presentationStyle = paywall.presentation.style
    super.init(nibName: nil, bundle: nil)
    loadPaywallWebpage()
    PaywallViewController.cache.insert(self)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

  deinit {
    PaywallViewController.cache.remove(self)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
		configureUI()
	}

  private func configureUI() {
    modalPresentationCapturesStatusBarAppearance = true
    setNeedsStatusBarAppearanceUpdate()
    view.backgroundColor = paywall.backgroundColor

    view.addSubview(webView)
    webView.alpha = 0.0

    let loadingColor = self.paywall.backgroundColor.readableOverlayColor
    view.addSubview(refreshPaywallButton)
    refreshPaywallButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)

    view.addSubview(exitButton)
    exitButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)

    NSLayoutConstraint.activate([
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

    // if the loading state is ready, re-template user attributes.
    if loadingState == .ready {
      webView.messageHandler.handle(.templateParamsAndUserAttributes)
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
    Superwall.delegate?.willDismissPaywall?()
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

  @MainActor
	func loadingStateDidChange(from oldValue: PaywallLoadingState) {
		guard loadingState != oldValue else {
      return
    }

    switch loadingState {
    case .unknown:
      break
    case .loadingPurchase:
      showRefreshButtonAfterTimeout(true, useModal: true)
      addLoadingView()
    case .loadingResponse:
      addShimmerView()
      showRefreshButtonAfterTimeout(true)
      UIView.springAnimate {
        self.webView.alpha = 0.0
        self.webView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -10)
      }
    case .ready:
      let translation = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
      webView.transform = oldValue == .loadingPurchase ? .identity : translation
      showRefreshButtonAfterTimeout(false)
      hideLoadingView()

      if oldValue != .loadingPurchase {
        UIView.animate(
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

  private func addLoadingView() {
    guard
      let background = Superwall.options.paywalls.transactionBackgroundView,
      background == .spinner
    else {
      return
    }

    if loadingViewController == nil {
      let loadingViewController = LoadingViewController(delegate: self)
      view.addSubview(loadingViewController.view)

      NSLayoutConstraint.activate([
        loadingViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        loadingViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        loadingViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
        loadingViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      ])
      self.loadingViewController = loadingViewController
    } else {
      loadingViewController?.show()
    }
  }

  private func hideLoadingView() {
    guard let loadingViewController = loadingViewController else {
      return
    }
    loadingViewController.hide()
  }

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

        let trackedEvent = InternalSuperwallEvent.PaywallWebviewLoad(
          state: .timeout,
          paywallInfo: self.paywallInfo
        )
        Superwall.track(trackedEvent)

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
      shouldSendDismissedState: false
    ) {
      Task {
        await Superwall.shared.presentAgain(using: self.presentationPublisher)
      }
    }
	}

	@objc func pressedExitPaywall() {
    dismiss(
      .withResult(
        paywallInfo: paywallInfo,
        state: .closed
      ),
      shouldSendDismissedState: true
    ) {
      PaywallManager.shared.removePaywall(withViewController: self)
    }
	}

  private func loadPaywallWebpage() {
    let url = paywall.url

    let trackedEvent = InternalSuperwallEvent.PaywallWebviewLoad(
      state: .start,
      paywallInfo: paywallInfo
    )
    Superwall.track(trackedEvent)

    if Superwall.options.paywalls.useCachedTemplates {
      let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
      webView.load(request)
    } else {
      let request = URLRequest(url: url)
      webView.load(request)
    }

    if paywall.webviewLoadingInfo.startAt == nil {
      paywall.webviewLoadingInfo.startAt = Date()
    }

    SessionEventsManager.shared.triggerSession.trackWebviewLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .start
    )

    loadingState = .loadingResponse
  }

	func trackOpen() {
    SessionEventsManager.shared.triggerSession.trackPaywallOpen()
    Storage.shared.saveLastPaywallView()
    Storage.shared.incrementTotalPaywallViews()
    let trackedEvent = InternalSuperwallEvent.PaywallOpen(paywallInfo: paywallInfo)
    Superwall.track(trackedEvent)
	}

	func trackClose() {
    SessionEventsManager.shared.triggerSession.trackPaywallClose()

    let trackedEvent = InternalSuperwallEvent.PaywallClose(paywallInfo: paywallInfo)
    Superwall.track(trackedEvent)
	}

  @MainActor
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
}

// MARK: - WebEventHandlerDelegate
extension PaywallViewController: WebEventHandlerDelegate {
  func eventDidOccur(_ paywallPresentationResult: PaywallPresentationResult) {
    Task {
      await delegate?.eventDidOccur(
        paywallViewController: self,
        result: paywallPresentationResult
      )
    }
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
      shouldSendDismissedState: true
    ) { [weak self] in
      self?.eventDidOccur(.openedDeepLink(url: url))
      UIApplication.shared.open(url)
    }
  }
}

// MARK: - presentation logic
extension PaywallViewController {
	func present(
    on presenter: UIViewController,
    eventData: EventData?,
    presentationStyleOverride: PaywallPresentationStyle?,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    presentationPublisher: PresentationSubject,
    completion: @escaping (Bool) -> Void
  ) {
		if Superwall.shared.isPaywallPresented
      || presenter is PaywallViewController
      || isBeingPresented {
      return completion(false)
		}

    addShimmerView(onPresent: true)
    prepareForPresentation()

    self.eventData = eventData
    self.paywallStatePublisher = paywallStatePublisher
    self.presentationPublisher = presentationPublisher

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
      backgroundColor: paywall.backgroundColor,
      tintColor: paywall.backgroundColor.readableOverlayColor,
      isLightBackground: !paywall.backgroundColor.isDarkColor
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
    _ dismissalResult: PaywallDismissedResult,
    shouldSendDismissedState: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    prepareToDismiss(withInfo: dismissalResult.paywallInfo)

		dismiss(animated: presentationIsAnimated) { [weak self] in
      self?.didDismiss(
        dismissalResult,
        shouldSendDismissedState: shouldSendDismissedState,
        completion: completion
      )
		}
	}

  private func prepareToDismiss(withInfo paywallInfo: PaywallInfo?) {
    calledDismiss = true
    Superwall.shared.latestDismissedPaywallInfo = paywallInfo
    Superwall.delegate?.willDismissPaywall?()
  }

  private func setPresentationStyle(withOverride presentationStyleOverride: PaywallPresentationStyle?) {
    presentationStyle = presentationStyleOverride ?? paywall.presentation.style

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
    _ dismissalResult: PaywallDismissedResult,
    shouldSendDismissedState: Bool = true,
    completion: (() -> Void)? = nil
  ) {
		isPresented = false
    if Superwall.options.isGameControllerEnabled && GameControllerManager.shared.delegate == self {
			GameControllerManager.shared.delegate = nil
		}
		Superwall.delegate?.didDismissPaywall?()

		if shouldSendDismissedState {
      paywallStatePublisher?.send(.dismissed(dismissalResult))
      paywallStatePublisher?.send(completion: .finished)
      paywallStatePublisher = nil
		}
		completion?()
		Superwall.shared.destroyPresentingWindow()
	}

	func prepareForPresentation() {
		readyForEventTracking = false
		willMove(toParent: nil)
		view.removeFromSuperview()
		removeFromParent()
		view.alpha = 1.0
		view.transform = .identity
		webView.scrollView.contentOffset = CGPoint.zero

		Superwall.delegate?.willPresentPaywall?()
		Superwall.shared.paywallWasPresentedThisSession = true
		Superwall.shared.recentlyPresented = true
	}

	func presentationDidFinish() {
		Superwall.delegate?.didPresentPaywall?()
		readyForEventTracking = true
		trackOpen()

    if Superwall.options.isGameControllerEnabled {
			GameControllerManager.shared.delegate = self
		}
    promptToSetDelegate()
	}

  private func promptToSetDelegate() {
    guard
      presentedViewController == nil,
      Superwall.delegate == nil
    else {
      return
    }
    let alertController = AlertControllerFactory.create(
      title: "Almost Done...",
      message: "Set Superwall.delegate to handle purchases, restores and more!",
      actionTitle: "Docs →",
      closeActionTitle: "Done",
      onClose: {
        if let url = URL(
          string: "https://docs.superwall.com/docs/configuring-the-sdk#conforming-to-the-delegate"
        ) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
      }
    )

    present(alertController, animated: true) { [weak self] in
      if let loadingState = self?.loadingState,
         loadingState != .loadingResponse {
        self?.loadingState = .ready
      }
    }
  }
}

// MARK: - SFSafariViewControllerDelegate
extension PaywallViewController: SFSafariViewControllerDelegate {
	func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
		isSafariVCPresented = false
	}
}

// MARK: - GameControllerDelegate
extension PaywallViewController: GameControllerDelegate {
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
extension PaywallViewController: Stubbable {
  static func stub() -> PaywallViewController {
    return PaywallViewController(
      paywall: .stub(),
      delegate: nil
    )
  }
}

// MARK: - UIViewControllerTransitioningDelegate
extension PaywallViewController: UIViewControllerTransitioningDelegate {
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
