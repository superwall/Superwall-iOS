//
//  File.swift
//  
//
//  Created by brian on 7/21/21.
//
// swiftlint:disable file_length implicitly_unwrapped_optional type_body_length

import WebKit
import UIKit
import Foundation
import SafariServices
import Combine

protocol PaywallViewControllerDelegate: AnyObject {
	@MainActor func eventDidOccur(
    _ paywallEvent: PaywallWebEvent,
    on paywallViewController: PaywallViewController
  ) async
}

enum PaywallLoadingState {
  /// The initial state of the paywall
  case unknown

  /// When a purchase is loading
  case loadingPurchase

  /// When the paywall URL is loading
  case loadingURL

  /// When the user has manually shown the spinner
  case manualLoading

  /// When everything has loaded.
  case ready
}

class PaywallViewController: UIViewController, SWWebViewDelegate, LoadingDelegate {
  // MARK: - Internal Properties
  override var preferredStatusBarStyle: UIStatusBarStyle {
    if let isDark = view.backgroundColor?.isDarkColor, isDark {
      return .lightContent
    }
    return .darkContent
  }
  /// The paywall to feed into the view controller.
  var paywall: Paywall

  /// The event data associated with the presentation of the paywall.
  var eventData: EventData?

  /// The cache key for the view controller.
  var cacheKey: String

  /// Determines whether the paywall is presented or not.
  var isActive: Bool {
    return isPresented || isBeingPresented
  }

  /// The web view that the paywall is displayed in.
  let webView: SWWebView

  /// The paywall info
  var paywallInfo: PaywallInfo {
    return paywall.getInfo(
      fromEvent: eventData,
      sessionEventsManager: sessionEventsManager
    )
  }

  /// The loading state of the paywall.
  var loadingState: PaywallLoadingState = .unknown {
    didSet {
      if loadingState != oldValue {
        loadingStateDidChange(from: oldValue)
      }
    }
  }

  // MARK: - Private Properties
  private weak var delegate: PaywallViewControllerDelegate?

  /// A publisher that emits ``PaywallState`` objects. These state objects feed back to
  /// the caller of ``Superwall/track(event:params:paywallOverrides:paywallHandler:)``
  ///
  /// This publisher is set on presentation of the paywall.
  private var paywallStatePublisher: PassthroughSubject<PaywallState, Never>!

  /// Defines whether the view controller is being presented or not.
  private var isPresented = false

  /// Defines whether dismiss has been called.
  private var calledDismiss = false

  /// A timer that shows the refresh buttons/modal when it fires.
	private var showRefreshTimer: Timer?

  /// Defines when Safari is presenting in app.
	private var isSafariVCPresented = false

  /// The presentation style for the paywall.
  private var presentationStyle: PaywallPresentationStyle

  /// Defines whether the presentation should animate based on the presentation style.
  private var presentationIsAnimated: Bool {
    return presentationStyle != .fullscreenNoAnimation
  }

  /// A loading spinner that appears when making a purchase.
  private var loadingViewController: LoadingViewController?

  /// A shimmer view that appears when loading the webpage.
  private var shimmerView: ShimmerView?

  /// A button that refreshes the paywall presentation.
  private lazy var refreshPaywallButton: UIButton = {
    ButtonFactory.make(
      imageNamed: "reload_paywall",
      target: self,
      action: #selector(pressedRefreshPaywall)
    )
	}()

  /// A button that exits the paywall.
  private lazy var exitButton: UIButton = {
    ButtonFactory.make(
      imageNamed: "exit_paywall",
      target: self,
      action: #selector(pressedExitPaywall)
    )
  }()

  /// The push presentation animation transition delegate.
  private let transitionDelegate = PushTransitionDelegate()

  /// Defines whether the refresh alert view controller has been created.
  private var hasRefreshAlertController = false

  /// Cancellable observer.
  private var resignActiveObserver: AnyCancellable?

  private unowned let sessionEventsManager: SessionEventsManager
  private unowned let storage: Storage
  private unowned let deviceHelper: DeviceHelper
  private unowned let paywallManager: PaywallManager
  private weak var cache: PaywallViewControllerCache?

	// MARK: - View Lifecycle

	init(
    paywall: Paywall,
    delegate: PaywallViewControllerDelegate? = nil,
    deviceHelper: DeviceHelper,
    sessionEventsManager: SessionEventsManager,
    storage: Storage,
    paywallManager: PaywallManager,
    webView: SWWebView,
    cache: PaywallViewControllerCache?
  ) {
    self.cache = cache
    self.cacheKey = PaywallCacheLogic.key(
      identifier: paywall.identifier,
      locale: deviceHelper.locale
    )
    self.deviceHelper = deviceHelper
		self.delegate = delegate
    self.sessionEventsManager = sessionEventsManager
    self.storage = storage
    self.paywall = paywall
    self.paywallManager = paywallManager
    self.webView = webView

    presentationStyle = paywall.presentation.style
    super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

  override func viewDidLoad() {
    super.viewDidLoad()
		configureUI()
    loadPaywallWebpage()
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

  nonisolated private func trackOpen() async {
    await sessionEventsManager.triggerSession.trackPaywallOpen()
    storage.trackPaywallOpen()
    let trackedEvent = await InternalSuperwallEvent.PaywallOpen(paywallInfo: paywallInfo)
    await Superwall.shared.track(trackedEvent)
  }

  nonisolated private func trackClose() async {
    let trackedEvent = await InternalSuperwallEvent.PaywallClose(paywallInfo: paywallInfo)
    await Superwall.shared.track(trackedEvent)
    await sessionEventsManager.triggerSession.trackPaywallClose()
  }

  @objc private func pressedRefreshPaywall() {
    dismiss(
      .withResult(
        paywallInfo: paywallInfo,
        state: .closed
      ),
      shouldSendDismissedState: false
    ) { [weak self] in
      guard let self = self else {
        return
      }
      Task {
        await Superwall.shared.presentAgain(cacheKey: self.cacheKey)
      }
    }
  }

  @objc private func pressedExitPaywall() {
    dismiss(
      .withResult(
        paywallInfo: paywallInfo,
        state: .closed
      ),
      shouldSendDismissedState: true
    ) { [weak self] in
      guard let self = self else {
        return
      }
      self.cache?.removePaywallViewController(forKey: self.cacheKey)
    }
  }

  private func loadPaywallWebpage() {
    let url = paywall.url

    if paywall.webviewLoadingInfo.startAt == nil {
      paywall.webviewLoadingInfo.startAt = Date()
    }

    Task(priority: .utility) {
      let trackedEvent = InternalSuperwallEvent.PaywallWebviewLoad(
        state: .start,
        paywallInfo: self.paywallInfo
      )
      await Superwall.shared.track(trackedEvent)
      await sessionEventsManager.triggerSession.trackWebviewLoad(
        forPaywallId: paywallInfo.databaseId,
        state: .start
      )
    }

    if Superwall.shared.options.paywalls.useCachedTemplates {
      let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
      webView.load(request)
    } else {
      let request = URLRequest(url: url)
      webView.load(request)
    }

    loadingState = .loadingURL
  }

  // MARK: - State Handling
  func togglePaywallSpinner(isHidden: Bool) {
    if isHidden {
      if loadingState == .manualLoading {
        loadingState = .ready
      }
    } else {
      if loadingState == .ready {
        loadingState = .manualLoading
      }
    }
  }

	func loadingStateDidChange(from oldValue: PaywallLoadingState) {
    switch loadingState {
    case .unknown:
      break
    case .loadingPurchase,
      .manualLoading:
      addLoadingView()
    case .loadingURL:
      addShimmerView()
      showRefreshButtonAfterTimeout(true)
      UIView.springAnimate {
        self.webView.alpha = 0.0
        self.webView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -10)
      }
    case .ready:
      let translation = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
      let spinnerDidShow = oldValue == .loadingPurchase || oldValue == .manualLoading
      webView.transform = spinnerDidShow ? .identity : translation
      showRefreshButtonAfterTimeout(false)
      hideLoadingView()

      if !spinnerDidShow {
        UIView.animate(
          withDuration: 0.6,
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

  private func addShimmerView(onPresent: Bool = false) {
    guard shimmerView == nil else {
      return
    }
    guard loadingState == .loadingURL || loadingState == .unknown else {
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
    view.insertSubview(shimmerView, belowSubview: webView)
    NSLayoutConstraint.activate([
      shimmerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      shimmerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      shimmerView.topAnchor.constraint(equalTo: view.topAnchor),
      shimmerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    self.shimmerView = shimmerView
  }

  private func addLoadingView() {
    guard
      let background = Superwall.shared.options.paywalls.transactionBackgroundView,
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

  // MARK: - Timeout

  private func showRefreshButtonAfterTimeout(_ isVisible: Bool) {
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

        self.view.bringSubviewToFront(self.refreshPaywallButton)
        self.view.bringSubviewToFront(self.exitButton)

        self.refreshPaywallButton.isHidden = false
        self.refreshPaywallButton.alpha = 0.0
        self.exitButton.isHidden = false
        self.exitButton.alpha = 0.0

        Task(priority: .utility) {
          let trackedEvent = InternalSuperwallEvent.PaywallWebviewLoad(
            state: .timeout,
            paywallInfo: self.paywallInfo
          )
          await Superwall.shared.track(trackedEvent)
        }

        UIView.springAnimate(withDuration: 2) {
          self.refreshPaywallButton.alpha = 1.0
          self.exitButton.alpha = 1.0
        }
      }
		} else {
			hideRefreshButton()
		}
	}

	private func hideRefreshButton() {
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

  // MARK: - Presentation Logic

  func present(
    on presenter: UIViewController,
    eventData: EventData?,
    presentationStyleOverride: PaywallPresentationStyle?,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
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

    setPresentationStyle(withOverride: presentationStyleOverride)

    if loadingState == .ready {
      webView.messageHandler.handle(.templateParamsAndUserAttributes)
    }

    presenter.present(
      self,
      animated: presentationIsAnimated
    ) { [weak self] in
      self?.presentationDidFinish()
      completion(true)
    }
  }

  private func setPresentationStyle(withOverride presentationStyleOverride: PaywallPresentationStyle?) {
    if let presentationStyleOverride = presentationStyleOverride,
      presentationStyleOverride != .none {
      presentationStyle = presentationStyleOverride
    } else {
      presentationStyle = paywall.presentation.style
    }

    switch presentationStyle {
    case .modal:
      modalPresentationStyle = .pageSheet
    case .fullscreen:
      modalPresentationStyle = .overFullScreen
    case .push:
      modalPresentationStyle = .custom
      transitioningDelegate = transitionDelegate
    case .fullscreenNoAnimation:
      modalPresentationStyle = .overFullScreen
    case .none:
      break
    }
  }

  private func prepareForPresentation() {
    willMove(toParent: nil)
    view.removeFromSuperview()
    removeFromParent()
    view.alpha = 1.0
    view.transform = .identity
    webView.scrollView.contentOffset = CGPoint.zero

    Superwall.shared.dependencyContainer.delegateAdapter.willPresentPaywall()
  }

  private func presentationDidFinish() {
    isPresented = true
    Superwall.shared.dependencyContainer.delegateAdapter.didPresentPaywall()
    Task(priority: .utility) {
      await trackOpen()
    }
    GameControllerManager.shared.setDelegate(self)
  }

  @MainActor
  func presentAlert(
    title: String? = nil,
    message: String? = nil,
    actionTitle: String? = nil,
    closeActionTitle: String = "Done",
    action: (() -> Void)? = nil,
    onClose: (() -> Void)? = nil
  ) {
    guard presentedViewController == nil else {
      return
    }
    let alertController = AlertControllerFactory.make(
      title: title,
      message: message,
      actionTitle: actionTitle,
      closeActionTitle: closeActionTitle,
      action: action,
      onClose: onClose,
      sourceView: self.view
    )

    present(alertController, animated: true) { [weak self] in
      if let loadingState = self?.loadingState,
        loadingState != .loadingURL {
        self?.loadingState = .ready
      }
    }
  }
}

// MARK: - PaywallMessageHandlerDelegate
extension PaywallViewController: PaywallMessageHandlerDelegate {
  func eventDidOccur(_ paywallEvent: PaywallWebEvent) {
    Task {
      await delegate?.eventDidOccur(
        paywallEvent,
        on: self
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

// MARK: - View Lifecycle
extension PaywallViewController {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    guard isActive else {
      return
    }

    cache?.activePaywallVcKey = cacheKey

    if isSafariVCPresented {
      return
    }

    if #available(iOS 15.0, *),
      !deviceHelper.isMac {
//       webView.setAllMediaPlaybackSuspended(false) // ignore-xcode-12
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
    willDismiss()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard isPresented else {
      return
    }
    if isSafariVCPresented {
      return
    }
    Task(priority: .utility) {
      await trackClose()
    }

    if #available(iOS 15.0, *),
      !deviceHelper.isMac {
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

  func dismiss(
    _ dismissalResult: PaywallDismissedResult,
    shouldSendDismissedState: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    calledDismiss = true
    willDismiss()

    dismiss(animated: presentationIsAnimated) { [weak self] in
      guard let self = self else {
        return
      }
      self.didDismiss(
        dismissalResult,
        shouldSendDismissedState: shouldSendDismissedState,
        completion: completion
      )
    }
  }

  private func willDismiss() {
    Superwall.shared.presentationItems.paywallInfo = paywallInfo
    Superwall.shared.dependencyContainer.delegateAdapter.willDismissPaywall()
  }

  private func didDismiss(
    _ dismissalResult: PaywallDismissedResult,
    shouldSendDismissedState: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    let isShowingSpinner = loadingState == .loadingPurchase || loadingState == .manualLoading
    if isShowingSpinner {
      self.loadingState = .ready
    }

    isPresented = false
    cache?.activePaywallVcKey = nil

    GameControllerManager.shared.clearDelegate(self)
    Superwall.shared.dependencyContainer.delegateAdapter.didDismissPaywall()

    if shouldSendDismissedState {
      paywallStatePublisher?.send(.dismissed(dismissalResult))
      paywallStatePublisher?.send(completion: .finished)
      paywallStatePublisher = nil
    }
    Superwall.shared.destroyPresentingWindow()
    completion?()
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
    guard let payload = event.jsonString else {
      return
    }
    let script = "window.paywall.accept([\(payload)])"
    webView.evaluateJavaScript(script)
    Logger.debug(
      logLevel: .debug,
      scope: .gameControllerManager,
      message: "Received Event",
      info: ["payload": payload],
      error: nil
    )
  }
}
