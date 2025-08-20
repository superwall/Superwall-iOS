//
//  File.swift
//
//
//  Created by brian on 7/21/21.
//
// swiftlint:disable file_length type_body_length function_body_length

import Combine
import SafariServices
import UIKit
import WebKit
import StoreKit

@objc(SWKPaywallViewController)
public class PaywallViewController: UIViewController, LoadingDelegate {
  // MARK: - Public Properties
  /// A publisher that emits ``PaywallState`` objects, which tell you the state of the presented paywall.
  public var statePublisher: AnyPublisher<PaywallState, Never>? {
    return paywallStateSubject?.eraseToAnyPublisher()
  }

  /// Defines whether the presentation should animate based on the presentation style.
  @objc public var presentationIsAnimated: Bool {
    return presentationStyle != .fullscreenNoAnimation
  }

  // MARK: - Internal Properties
  override public var preferredStatusBarStyle: UIStatusBarStyle {
    if let isDark = view.backgroundColor?.isDarkColor, isDark {
      return .lightContent
    }
    return .darkContent
  }
  /// The paywall to feed into the view controller.
  var paywall: Paywall

  /// The request associated with the presentation of the paywall.
  var request: PresentationRequest?

  /// The cache key for the view controller.
  var cacheKey: String

  /// Determines whether the paywall is presented or not.
  var isActive: Bool {
    return isPresented || isBeingPresented
  }

  /// The webview that the paywall is displayed in.
  let webView: SWWebView

  /// The paywall info
  @objc public var info: PaywallInfo {
    return paywall.getInfo(
      fromPlacement: request?.presentationInfo.placementData
    )
  }

  /// A published property that indicates the loading state of the paywall.
  ///
  /// This is a published value
  @Published public internal(set) var loadingState: PaywallLoadingState = .unknown {
    didSet {
      if loadingState != oldValue {
        loadingStateDidChange(from: oldValue)
        delegate?.loadingStateDidChange(
          paywall: self,
          loadingState: loadingState
        )
      }
    }
  }

  var delegate: PaywallViewControllerDelegateAdapter?

  typealias Factory = TriggerFactory
    & RestoreAccessFactory
    & AppIdFactory

  // MARK: - Private Properties
  /// Internal passthrough subject that emits ``PaywallState`` objects. These state objects feed back to
  /// the caller of ``Superwall/register(placement:params:handler:feature:)``
  ///
  /// This publisher is set on presentation of the paywall.
  private var paywallStateSubject: PassthroughSubject<PaywallState, Never>?

  private weak var eventDelegate: PaywallViewControllerEventDelegate?

  /// Defines whether the view controller is being presented or not.
  private var isPresented = false

  /// Stores the completion block when calling dismiss.
  private var dismissCompletionBlock: (() -> Void)?

  /// Stores the ``PaywallResult`` on dismiss of paywall.
  private var paywallResult: PaywallResult?

  /// A timer that shows the refresh buttons/modal when it fires.
  private var showRefreshTimer: Timer?

  /// Defines when Safari is presenting in app.
  var isSafariVCPresented = false

  /// The presentation style for the paywall.
  private var presentationStyle: PaywallPresentationStyle

  /// Constraints for popup content sizing
  private var popupWidthConstraint: NSLayoutConstraint?
  private var popupHeightConstraint: NSLayoutConstraint?
  var popupContainerView: UIView?

  /// Internal property for transition logic
  var isCustomBackgroundDismissal = false

  /// The background color of the paywall, depending on whether the device is in dark mode.
  private var backgroundColor: UIColor {
    #if os(visionOS)
      return paywall.backgroundColor
    #else
      let style = UIScreen.main.traitCollection.userInterfaceStyle
      switch style {
      case .dark:
        return paywall.darkBackgroundColor ?? paywall.backgroundColor
      default:
        return paywall.backgroundColor
      }
    #endif
  }

  /// A loading spinner that appears when making a purchase.
  private var loadingViewController: LoadingViewController?

  /// A shimmer view that appears when loading the webpage.
  private var shimmerView: ShimmerView?

  /// A button that refreshes the paywall presentation.
  private lazy var refreshPaywallButton: UIButton = {
    ButtonFactory.make(
      imageNamed: "SuperwallKit_reload_paywall",
      target: self,
      action: #selector(reloadWebView)
    )
  }()

  /// A button that exits the paywall.
  private lazy var exitButton: UIButton = {
    ButtonFactory.make(
      imageNamed: "SuperwallKit_exit_paywall",
      target: self,
      action: #selector(forceClose)
    )
  }()

  /// The push presentation animation transition delegate.
  private let transitionDelegate = PushTransitionDelegate()
  /// The popup presentation animation transition delegate.
  private let popupTransitionDelegate = PopupTransitionDelegate()

  /// Defines whether the refresh alert view controller has been created.
  private var hasRefreshAlertController = false

  /// Cancellable observer.
  private var resignActiveObserver: AnyCancellable?

  private var presentationWillPrepare = true
  private var presentationDidFinishPrepare = false
  private var didCallDelegate = false

  /// `true` if there's a survey to complete and the paywall is displayed in a modal style.
  private var didDisableSwipeForSurvey = false

  /// Whether the survey was shown, not shown, or in a holdout. Defaults to not shown.
  private var surveyPresentationResult: SurveyPresentationResult = .noShow

  /// If the user matches an audience with an occurrence, this needs to be saved on
  /// paywall presentation.
  private var unsavedOccurrence: TriggerAudienceOccurrence?

  private var lastOpen: Date?

  private struct PopupDimensions {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
  }

  private unowned let factory: Factory
  private unowned let storage: Storage
  private unowned let deviceHelper: DeviceHelper
  private weak var cache: PaywallViewControllerCache?
  private weak var paywallArchiveManager: PaywallArchiveManager?

  // MARK: - View Lifecycle

  init(
    paywall: Paywall,
    eventDelegate: PaywallViewControllerEventDelegate? = nil,
    delegate: PaywallViewControllerDelegateAdapter? = nil,
    deviceHelper: DeviceHelper,
    factory: Factory,
    storage: Storage,
    webView: SWWebView,
    cache: PaywallViewControllerCache?,
    paywallArchiveManager: PaywallArchiveManager?
  ) {
    self.cache = cache
    self.paywallArchiveManager = paywallArchiveManager
    self.cacheKey = PaywallCacheLogic.key(
      identifier: paywall.identifier,
      locale: deviceHelper.localeIdentifier
    )
    self.deviceHelper = deviceHelper
    self.eventDelegate = eventDelegate
    self.delegate = delegate

    self.factory = factory
    self.storage = storage
    self.paywall = paywall
    self.webView = webView

    presentationStyle = paywall.presentation.style
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    configureUI()
    loadWebView()
  }

  private func configureUI() {
    modalPresentationCapturesStatusBarAppearance = true
    #if !os(visionOS)
      setNeedsStatusBarAppearanceUpdate()
    #endif
    // Don't set background color for popup - it will be transparent
    switch presentationStyle {
    case .popup:
      break
    default:
      view.backgroundColor = backgroundColor
      view.addSubview(webView)
      webView.alpha = 0.0
      NSLayoutConstraint.activate([
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        webView.topAnchor.constraint(equalTo: view.topAnchor),
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      ])
    }

    let loadingColor = backgroundColor.readableOverlayColor
    view.addSubview(refreshPaywallButton)
    refreshPaywallButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)

    view.addSubview(exitButton)
    exitButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)

    NSLayoutConstraint.activate([
      refreshPaywallButton.topAnchor.constraint(
        equalTo: view.layoutMarginsGuide.topAnchor, constant: 17),
      refreshPaywallButton.trailingAnchor.constraint(
        equalTo: view.layoutMarginsGuide.trailingAnchor, constant: 0),
      refreshPaywallButton.widthAnchor.constraint(equalToConstant: 55),
      refreshPaywallButton.heightAnchor.constraint(equalToConstant: 55),

      exitButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 17),
      exitButton.leadingAnchor.constraint(
        equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 0),
      exitButton.widthAnchor.constraint(equalToConstant: 55),
      exitButton.heightAnchor.constraint(equalToConstant: 55)
    ])
  }

  nonisolated private func trackOpen() async {
    await MainActor.run {
      lastOpen = Date()
    }
    await storage.trackPaywallOpen()
    await webView.messageHandler.handle(.paywallOpen)

    let demandScore = await deviceHelper.enrichment?.device["demandScore"].int
    let demandTier = await deviceHelper.enrichment?.device["demandTier"].string

    let paywallOpen = await InternalSuperwallEvent.PaywallOpen(
      paywallInfo: info,
      demandScore: demandScore,
      demandTier: demandTier
    )
    await Superwall.shared.track(paywallOpen)
  }

  nonisolated private func trackClose() async {
    await MainActor.run {
      lastOpen = nil
    }
    let paywallClose = await InternalSuperwallEvent.PaywallClose(
      paywallInfo: info,
      surveyPresentationResult: surveyPresentationResult
    )
    await webView.messageHandler.handle(.paywallClose)
    await Superwall.shared.track(paywallClose)
  }

  /// Triggered by user closing the paywall when the webview hasn't loaded.
  @objc private func forceClose() {
    dismiss(
      result: .declined,
      closeReason: .systemLogic
    ) { [weak self] in
      guard let self = self else {
        return
      }
      self.cache?.removePaywallViewController(forKey: self.cacheKey)
    }
  }

  func loadWebView() {
    if paywall.webviewLoadingInfo.startAt == nil {
      paywall.webviewLoadingInfo.startAt = Date()
    }

    Task(priority: .utility) {
      let webviewLoad = InternalSuperwallEvent.PaywallWebviewLoad(
        state: .start,
        paywallInfo: self.info
      )
      await Superwall.shared.track(webviewLoad)
    }

    loadingState = .loadingURL

    if let paywallArchiveManager = self.paywallArchiveManager,
      paywallArchiveManager.shouldAlwaysUseWebArchive(manifest: paywall.manifest) {
      Task {
        if let url = await paywallArchiveManager.getArchiveURL(forManifest: paywall.manifest) {
          loadWebViewFromArchive(url: url)
        } else {
          // Fallback to old way if couldn't get archive
          await webView.loadURL(from: paywall)
        }
      }
      return
    }

    if let webArchiveURL = paywallArchiveManager?.getCachedArchiveURL(manifest: paywall.manifest) {
      loadWebViewFromArchive(url: webArchiveURL)
    } else {
      Task {
        await webView.loadURL(from: paywall)
      }
    }

    webView.scrollView.isScrollEnabled = paywall.isScrollEnabled
  }

  func closeSafari(completion: (() -> Void)? = nil) {
    guard
      isSafariVCPresented,
      let safariVC = presentedViewController as? SFSafariViewController
    else {
      completion?()
      return
    }
    safariVC.dismiss(
      animated: true,
      completion: completion
    )
    // Must set this maually because programmatically dismissing the SafariVC doesn't call its
    // delegate method where we set this.
    isSafariVCPresented = false
  }

  private func loadWebViewFromArchive(url: URL) {
    webView.loadFileURL(url, allowingReadAccessTo: url)
  }

  @objc private func reloadWebView() {
    webView.reload()
  }

  // MARK: - State Handling

  /// Hides or displays the paywall spinner.
  ///
  /// - Parameter isHidden: A `Bool` indicating whether to show or hide the spinner.
  public func togglePaywallSpinner(isHidden: Bool) {
    if isHidden {
      if loadingState == .manualLoading || loadingState == .loadingPurchase {
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
          completion: { [weak self] _ in
            guard let self = self else {
              return
            }
            self.shimmerView?.removeFromSuperview()
            self.shimmerView = nil

            Task.detached { [weak self] in
              guard let self = self else {
                return
              }
              let shimmerEndDate = Date()
              await MainActor.run {
                self.paywall.shimmerLoadingInfo.endAt = shimmerEndDate
              }

              let visibleDuration: Double = await MainActor.run {
                if let lastOpen = self.lastOpen {
                  return max(
                    0, shimmerEndDate.timeIntervalSince1970 - lastOpen.timeIntervalSince1970)
                } else {
                  return 0.0
                }
              }
              let shimmerComplete = await InternalSuperwallEvent.ShimmerLoad(
                state: .complete,
                paywallId: self.paywall.identifier,
                visibleDuration: visibleDuration
              )
              await Superwall.shared.track(shimmerComplete)
            }
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
      backgroundColor: backgroundColor,
      tintColor: backgroundColor.readableOverlayColor,
      isLightBackground: !backgroundColor.isDarkColor
    )

    let shimmerSuperview: UIView
    switch presentationStyle {
    case .popup:
      // For popup style, use the popup container
      shimmerSuperview = popupContainerView ?? view

      // Apply the same corner radius as the popup to the shimmer view
      if let dimensions = getPopupDimensions() {
        shimmerView.layer.cornerRadius = dimensions.cornerRadius
        shimmerView.layer.masksToBounds = true
      }
    default:
      shimmerSuperview = view
    }

    shimmerSuperview.insertSubview(shimmerView, belowSubview: webView)

    NSLayoutConstraint.activate([
      shimmerView.leadingAnchor.constraint(equalTo: shimmerSuperview.leadingAnchor),
      shimmerView.trailingAnchor.constraint(equalTo: shimmerSuperview.trailingAnchor),
      shimmerView.topAnchor.constraint(equalTo: shimmerSuperview.topAnchor),
      shimmerView.bottomAnchor.constraint(equalTo: shimmerSuperview.bottomAnchor)
    ])
    self.shimmerView = shimmerView
    Task {
      paywall.shimmerLoadingInfo.startAt = Date()

      let shimmerStart = InternalSuperwallEvent.ShimmerLoad(
        state: .start,
        paywallId: paywall.identifier
      )
      await Superwall.shared.track(shimmerStart)
    }
  }

  private func addLoadingView() {
    guard Superwall.shared.options.paywalls.transactionBackgroundView == .spinner else {
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
          let webviewTimeout = await InternalSuperwallEvent.PaywallWebviewLoad(
            state: .timeout,
            paywallInfo: self.info
          )
          await Superwall.shared.track(webviewTimeout)
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

  /// Sets data before presenting the paywall.
  func set(
    request: PresentationRequest,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    unsavedOccurrence: TriggerAudienceOccurrence?
  ) {
    self.request = request
    self.paywallStateSubject = paywallStatePublisher
    self.unsavedOccurrence = unsavedOccurrence
  }

  func present(
    on presenter: UIViewController,
    request: PresentationRequest,
    unsavedOccurrence: TriggerAudienceOccurrence?,
    presentationStyleOverride: PaywallPresentationStyle?,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    completion: @escaping (Bool) -> Void
  ) {
    if Superwall.shared.isPaywallPresented
      || presenter is PaywallViewController
      || isBeingPresented {
      return completion(false)
    }
    Superwall.shared.presentationItems.window?.makeKeyAndVisible()

    set(
      request: request,
      paywallStatePublisher: paywallStatePublisher,
      unsavedOccurrence: unsavedOccurrence
    )

    setPresentationStyle(withOverride: presentationStyleOverride)

    presenter.present(
      self,
      animated: presentationIsAnimated
    ) {
      completion(true)
    }
  }

  private func setPresentationStyle(withOverride override: PaywallPresentationStyle?) {
    if let override = override,
      override != .none {
      presentationStyle = override
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
    case let .drawer(height, cornerRadius):
      modalPresentationStyle = .pageSheet
      #if !os(visionOS)
        if #available(iOS 16.0, *),
          UIDevice.current.userInterfaceIdiom == .phone {
          let heightRatio = height / 100
          sheetPresentationController?.detents = [
            .custom { context in
              return heightRatio * context.maximumDetentValue
            }
          ]
          sheetPresentationController?.preferredCornerRadius = cornerRadius
        }
      #endif
    case .popup:
      modalPresentationStyle = .custom
      transitioningDelegate = popupTransitionDelegate
      setupPopupBackground()
    case .none:
      break
    }
  }

  private func getPopupDimensions() -> PopupDimensions? {
    guard case .popup(let height, let width, let cornerRadius) = presentationStyle else {
      return nil
    }

    // Width and height are percentages, cornerRadius is in pixels
    let screenWidth = view.bounds.width
    let screenHeight = view.bounds.height

    let calculatedWidth = screenWidth * CGFloat(width / 100.0)
    let calculatedHeight = screenHeight * CGFloat(height / 100.0)

    return PopupDimensions(
      width: calculatedWidth,
      height: calculatedHeight,
      cornerRadius: CGFloat(cornerRadius)
    )
  }

  private func setupPopupBackground() {
    // Set transparent background for the main view
    view.backgroundColor = .clear

    // Create a semi-transparent background view matching iOS alert style
    let backgroundView = UIView()
    backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.alpha = 0.0 // Start transparent for animation
    view.insertSubview(backgroundView, at: 0)

    NSLayoutConstraint.activate([
      backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    // Add tap gesture to dismiss on background tap
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
    backgroundView.addGestureRecognizer(tapGesture)

    // Animate background to visible
    UIView.animate(withDuration: 0.3) {
      backgroundView.alpha = 1.0
    }

    // Extract popup dimensions and corner radius from presentation style
    guard let dimensions = getPopupDimensions() else {
      return
    }

    // Create container view for the webview to handle centering
    let containerView = UIView()
    containerView.translatesAutoresizingMaskIntoConstraints = false
    containerView.backgroundColor = .clear
    view.addSubview(containerView)
    popupContainerView = containerView

    // Style container view with corner radius and shadow
    containerView.layer.cornerRadius = dimensions.cornerRadius
    containerView.layer.shadowColor = UIColor.black.cgColor
    containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
    containerView.layer.shadowRadius = 10
    containerView.layer.shadowOpacity = 0.3
    containerView.layer.masksToBounds = false

    // Style webview - ensure no background conflicts and clip to container bounds
    webView.backgroundColor = .clear
    webView.isOpaque = false
    webView.layer.cornerRadius = dimensions.cornerRadius
    webView.layer.masksToBounds = true

    // Move webview to container
    containerView.addSubview(webView)

    // Set up size constraints for popup using presentation style dimensions
    let popupWidthConstraint = containerView.widthAnchor.constraint(equalToConstant: dimensions.width)
    self.popupWidthConstraint = popupWidthConstraint
    let popupHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: dimensions.height)
    self.popupHeightConstraint = popupHeightConstraint
    popupWidthConstraint.priority = UILayoutPriority(999)
    popupHeightConstraint.priority = UILayoutPriority(999)

    // Center container in view
    NSLayoutConstraint.activate([
      containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      popupWidthConstraint,
      popupHeightConstraint
    ])

    // Set webview constraints within container - fill the container exactly
    webView.translatesAutoresizingMaskIntoConstraints = false

    // Enable content size calculation for webview
    webView.scrollView.isScrollEnabled = true
    webView.scrollView.bounces = false
    webView.scrollView.showsVerticalScrollIndicator = false
    webView.scrollView.showsHorizontalScrollIndicator = false

    NSLayoutConstraint.activate([
      webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      webView.topAnchor.constraint(equalTo: containerView.topAnchor),
      webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ])
  }


  @objc private func backgroundTapped() {
    // Custom animation for popup dismissal on background tap
    isCustomBackgroundDismissal = true
    animatePopupDismissal {
      self.dismiss(result: .declined, closeReason: .manualClose)
    }
  }

  private func animatePopupDismissal(completion: @escaping () -> Void) {
    guard let containerView = popupContainerView else {
      completion()
      return
    }

    // Find the background view
    let backgroundView = view.subviews.first { subview in
      subview.backgroundColor == UIColor.black.withAlphaComponent(0.4)
    }

    // Animate popup scale down and background fade out simultaneously
    UIView.animate(
      withDuration: 0.25,
      delay: 0,
      options: [.curveEaseInOut, .beginFromCurrentState],
      animations: {
        // Scale down the popup container (foreground)
        containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        containerView.alpha = 0.0

        // Fade out the background
        backgroundView?.alpha = 0.0
      },
      completion: { [weak self] _ in
        // Reset the flag after custom animation completes
        self?.isCustomBackgroundDismissal = false
        completion()
      }
    )
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

    var model: [Action] = []
    if let actionTitle = actionTitle,
      let action = action {
      model = [Action(title: actionTitle, call: action)]
    }

    let alertController = AlertControllerFactory.make(
      title: title,
      message: message,
      closeActionTitle: closeActionTitle,
      actions: model,
      onClose: onClose,
      sourceView: self.view
    )

    present(alertController, animated: true) { [weak self] in
      self?.loadingState = .ready
    }
  }
}

// MARK: - SWWebViewDelegate
extension PaywallViewController: SWWebViewDelegate {
  func webViewDidFail() {
    handleWebViewFailure()
  }

  private func handleWebViewFailure() {
    guard isActive else {
      return
    }
    dismiss(
      result: .declined,
      closeReason: .webViewFailedToLoad
    )
  }
}

// MARK: - UIAdaptivePresentationControllerDelegate
extension PaywallViewController: UIAdaptivePresentationControllerDelegate {
  public func presentationControllerDidAttemptToDismiss(
    _ presentationController: UIPresentationController
  ) {
    dismiss(
      result: .declined,
      closeReason: .manualClose
    )
  }
}

// MARK: - PaywallMessageHandlerDelegate
extension PaywallViewController: PaywallMessageHandlerDelegate {
  func eventDidOccur(_ paywallEvent: PaywallWebEvent) {
    Task {
      await eventDelegate?.eventDidOccur(
        paywallEvent,
        on: self
      )
    }
  }

  func presentSafariInApp(_ url: URL) {
    guard let sharedApplication = UIApplication.sharedApplication else {
      return
    }
    guard sharedApplication.canOpenURL(url) else {
      Logger.debug(
        logLevel: .warn,
        scope: .paywallViewController,
        message: "Invalid URL provided for \"Open URL\" click behavior."
      )
      return
    }
    let safariVC = SFSafariViewController(url: url)
    #if !os(visionOS)
      safariVC.delegate = self
    #endif
    self.isSafariVCPresented = true
    present(safariVC, animated: true)
  }

  func presentSafariExternal(_ url: URL) {
    guard let sharedApplication = UIApplication.sharedApplication else {
      return
    }
    sharedApplication.open(url)
  }

  func openDeepLink(_ url: URL) {
    dismiss(
      result: .declined,
      closeReason: .systemLogic
    ) { [weak self] in
      self?.eventDidOccur(.openedDeepLink(url: url))
      guard let sharedApplication = UIApplication.sharedApplication else {
        return
      }
      sharedApplication.open(url)
    }
  }

  func requestReview(type: ReviewType) {
    switch type {
    case .inApp:
      if let scene = view.window?.windowScene {
        if #available(iOS 16.0, *) {
          AppStore.requestReview(in: scene)
        } else if #available(iOS 14.0, *) {
          SKStoreReviewController.requestReview(in: scene)
        } else {
          SKStoreReviewController.requestReview()
        }
      } else {
        SKStoreReviewController.requestReview()
      }
    case .external:
      let appId: String
      if let iosAppId = factory.makeAppId() {
        appId = iosAppId
      } else if let iosAppId = ReceiptManager.appId {
        appId = "\(iosAppId)"
      } else {
        Logger.debug(
          logLevel: .warn,
          scope: .superwallCore,
          message: "Unable to open external review URL. Please enter your Apple App ID on the Superwall dashboard."
        )
        return
      }

      if let url = URL(string: "https://apps.apple.com/app/id\(appId)?action=write-review") {
        UIApplication.shared.open(url)
      }
    }
  }
}

// MARK: - View Lifecycle
extension PaywallViewController {
  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    cache?.activePaywallVcKey = cacheKey

    if isSafariVCPresented {
      return
    }

    if #available(iOS 15.0, *),
      !deviceHelper.isMac {
      webView.setAllMediaPlaybackSuspended(false)  // ignore-xcode-12
    }

    if webView.loadingHandler.didFailToLoad {
      loadWebView()
    }

    presentationWillBegin()
  }

  /// Determines whether a survey will show.
  private var willShowSurvey: Bool {
    if paywall.surveys.isEmpty {
      return false
    }
    guard
      modalPresentationStyle == .formSheet || modalPresentationStyle == .pageSheet
        || modalPresentationStyle == .popover
    else {
      return false
    }
    guard presentationController?.delegate == nil else {
      return false
    }

    for survey in paywall.surveys where survey.hasSeenSurvey(storage: storage) {
      return false
    }
    return true
  }

  /// Prepares the view controller for presentation. Only called once per presentation.
  private func presentationWillBegin() {
    guard presentationWillPrepare else {
      return
    }
    if willShowSurvey {
      didDisableSwipeForSurvey = true
      presentationController?.delegate = self
      isModalInPresentation = true
    }
    addShimmerView(onPresent: true)

    view.alpha = 1.0
    view.transform = .identity

    didCallDelegate = false
    paywall.closeReason = .none
    Superwall.shared.dependencyContainer.delegateAdapter.willPresentPaywall(withInfo: info)

    webView.scrollView.contentOffset = CGPoint.zero
    if loadingState == .ready {
      webView.messageHandler.handle(.templateParamsAndUserAttributes)
    }

    presentationWillPrepare = false
  }

  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    presentationDidFinish()
  }

  /// Lets the view controller know that presentation has finished. Only called once per presentation.
  private func presentationDidFinish() {
    if presentationDidFinishPrepare {
      return
    }
    if let paywallStateSubject = paywallStateSubject {
      Superwall.shared.storePresentationObjects(
        request: request,
        paywallStatePublisher: paywallStateSubject,
        featureGatingBehavior: paywall.featureGating
      )
    }
    if let unsavedOccurrence = unsavedOccurrence {
      storage.coreDataManager.save(triggerAudienceOccurrence: unsavedOccurrence)
      self.unsavedOccurrence = nil
    }
    isPresented = true
    Superwall.shared.dependencyContainer.delegateAdapter.didPresentPaywall(withInfo: info)
    Task {
      await trackOpen()
    }
    GameControllerManager.shared.setDelegate(self)
    presentationDidFinishPrepare = true
  }

  override public func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    guard isPresented else {
      return
    }
    if isSafariVCPresented {
      return
    }

    willDismiss()
  }

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard isPresented else {
      return
    }
    if isSafariVCPresented {
      return
    }
    Task {
      await trackClose()
    }

    if #available(iOS 15.0, *),
      !deviceHelper.isMac {
      webView.setAllMediaPlaybackSuspended(true)  // ignore-xcode-12
    }

    resetPresentationPreparations()
    Task {
      await didDismiss()
    }
  }

  private func resetPresentationPreparations() {
    presentationWillPrepare = true
    presentationDidFinishPrepare = false
  }

  func dismiss(
    result: PaywallResult,
    closeReason: PaywallCloseReason,
    completion: (() -> Void)? = nil
  ) {
    dismissCompletionBlock = completion
    paywallResult = result
    paywall.closeReason = closeReason

    let isDeclined = paywallResult == .declined
    let isManualClose = closeReason == .manualClose

    func dismissView() async {
      if isDeclined, isManualClose {
        let paywallDecline = InternalSuperwallEvent.PaywallDecline(paywallInfo: info)

        let presentationResult = await Superwall.shared.internallyGetPresentationResult(
          forPlacement: paywallDecline,
          requestType: .paywallDeclineCheck
        )
        let presentingPlacement = info.presentedByPlacementWithName
        let presentedByPaywallDecline =
          presentingPlacement == SuperwallEventObjc.paywallDecline.description
        let presentedByTransactionAbandon =
          presentingPlacement == SuperwallEventObjc.transactionAbandon.description
        let presentedByTransactionFail =
          presentingPlacement == SuperwallEventObjc.transactionFail.description

        await Superwall.shared.track(paywallDecline)

        if case .paywall = presentationResult,
          !presentedByPaywallDecline,
          !presentedByTransactionAbandon,
          !presentedByTransactionFail {
          // If a paywall_decline trigger is active and the current paywall wasn't presented
          // by paywall_decline, transaction_abandon, or transaction_fail, it lands here so
          // as not to dismiss the paywall. track() will do that before presenting the next paywall.
          return
        }
      }
      if let delegate = delegate {
        didCallDelegate = true
        delegate.didFinish(
          paywall: self,
          result: result,
          shouldDismiss: true
        )
      } else {
        await dismiss(animated: presentationIsAnimated)
      }
    }

    SurveyManager.presentSurveyIfAvailable(
      paywall.surveys,
      paywallResult: result,
      paywallCloseReason: closeReason,
      using: self,
      loadingState: loadingState,
      isDebuggerLaunched: request?.flags.isDebuggerLaunched == true,
      paywallInfo: info,
      storage: storage,
      factory: factory
    ) { [weak self] result in
      self?.surveyPresentationResult = result
      Task {
        await dismissView()
      }
    }
  }

  private func willDismiss() {
    Superwall.shared.presentationItems.paywallInfo = info
    Superwall.shared.dependencyContainer.delegateAdapter.willDismissPaywall(withInfo: info)
  }

  private func didDismiss() async {
    // Reset spinner
    let isShowingSpinner = loadingState == .loadingPurchase || loadingState == .manualLoading
    if isShowingSpinner {
      self.loadingState = .ready
    }

    let state = await webView.messageHandler.getState()
    paywall.state = state

    let result = paywallResult ?? .declined

    // Reset state
    Superwall.shared.destroyPresentingWindow()
    GameControllerManager.shared.clearDelegate(self)

    if didDisableSwipeForSurvey {
      presentationController?.delegate = nil
      isModalInPresentation = false
      didDisableSwipeForSurvey = false
    }

    paywallResult = nil
    cache?.activePaywallVcKey = nil
    isPresented = false

    dismissCompletionBlock?()
    dismissCompletionBlock = nil

    paywallStateSubject?.send(.dismissed(info, result))

    if !didCallDelegate {
      delegate?.didFinish(
        paywall: self,
        result: result,
        shouldDismiss: false
      )
    }

    if paywall.closeReason.stateShouldComplete {
      paywallStateSubject?.send(completion: .finished)
      paywallStateSubject = nil
    }

    Superwall.shared.dependencyContainer.delegateAdapter.didDismissPaywall(withInfo: info)
  }
}

#if !os(visionOS)
  // MARK: - SFSafariViewControllerDelegate
  extension PaywallViewController: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
      isSafariVCPresented = false
    }
  }
#endif

// MARK: - GameControllerDelegate
extension PaywallViewController: GameControllerDelegate {
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
