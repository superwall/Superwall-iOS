//
//  File.swift
//
//
//  Created by brian on 7/21/21.
//
// swiftlint:disable file_length type_body_length function_body_length

import Combine
#if !os(macOS)
import SafariServices
#endif
import StoreKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import WebKit

@objc(SWKPaywallViewController)
public class PaywallViewController: PlatformViewController, LoadingDelegate {
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
  #if !os(macOS)
  override public var preferredStatusBarStyle: UIStatusBarStyle {
    if let isDark = view.backgroundColor?.isDarkColor, isDark {
      return .lightContent
    }
    return .darkContent
  }
  #endif
  /// The paywall to feed into the view controller.
  var paywall: Paywall

  /// The request associated with the presentation of the paywall.
  var request: PresentationRequest?

  /// The cache key for the view controller.
  var cacheKey: String

  /// What a request applies when it claims the view controller.
  ///
  /// The occurrence and publisher are cleared once used, so restoring the
  /// claim later doesn't save the occurrence again or reinstall a publisher
  /// that has already completed.
  private final class Claim {
    let request: PresentationRequest
    let paywall: Paywall
    var paywallStatePublisher: PassthroughSubject<PaywallState, Never>?
    var unsavedOccurrence: TriggerAudienceOccurrence?

    init(
      request: PresentationRequest,
      paywall: Paywall,
      paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
      unsavedOccurrence: TriggerAudienceOccurrence?
    ) {
      self.request = request
      self.paywall = paywall
      self.paywallStatePublisher = paywallStatePublisher
      self.unsavedOccurrence = unsavedOccurrence
    }
  }

  /// The claim currently applied to the view controller.
  private var currentClaim: Claim?

  /// The claim made through `getPaywall`. Kept so that a view controller the
  /// app is holding reports that placement when the app shows it, even if the
  /// SDK presented this paywall for another placement in the meantime.
  ///
  /// This is held for the life of the cached view controller on purpose: the
  /// app can show the handle it was given at any time.
  private var handedOutClaim: Claim?

  /// Whether the SDK claimed the view controller after it was handed out.
  private var handedOutClaimNeedsRestoring = false

  /// Whether the SDK started the current presentation via ``present(on:request:paywall:unsavedOccurrence:presentationStyleOverride:paywallStatePublisher:completion:)``.
  private var isPresentedBySDK = false

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

  var delegate: PaywallViewControllerDelegateAdapter? {
    didSet {
      syncCustomCallbackRegistration()
    }
  }

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

  /// Tracks if a redeem succeeded while the checkout web view is open.
  /// Used to prevent tracking transaction abandon when redeem succeeds.
  private var didRedeemSucceedDuringCheckout = false

  /// Work item for tracking transaction abandon, can be cancelled if redeem succeeds.
  private var transactionAbandonWorkItem: DispatchWorkItem?

  /// Tracks if checkout is being dismissed programmatically (e.g., via closeSafari).
  private var isCheckoutDismissedProgrammatically = false

  /// Tracks whether explicit stripe_checkout_abandon was already received for this checkout flow.
  private var didReceiveStripeCheckoutAbandonMessage = false

  /// What the user sees of a teleport's waiting screen while leaving and coming back.
  private var existingTeleportReturnCover: TeleportReturnCover?

  /// The product bought from this presentation, App Store or web. A close that
  /// follows a purchase, such as a `close` among the button's after-purchase
  /// actions, finishes the presentation as purchased rather than declined.
  private(set) var completedPurchaseProduct: StoreProduct?

  /// Ensures Stripe checkout callbacks are forwarded to WebEntitlementRedeemer in order.
  private let stripeCheckoutCoordinator = SerialTaskCoordinator()

  /// Manages intro offer eligibility tokens for SK2 purchases on iOS 18.2+
  let introOfferTokenManager: IntroOfferTokenManager

  #if !os(visionOS)
    /// Reference to the current checkout webview controller
    private weak var currentCheckoutVC: CheckoutWebViewController?
  #endif

  /// The presentation style for the paywall.
  private var presentationStyle: PaywallPresentationStyle

  /// Constraints for popup content sizing
  private var popupWidthConstraint: NSLayoutConstraint?
  private var popupHeightConstraint: NSLayoutConstraint?
  var popupContainerView: PlatformView?

  /// Internal property for transition logic testing
  var isCustomBackgroundDismissal = false

  /// The background color of the paywall, depending on whether the device is in dark mode.
  private var backgroundColor: PlatformColor {
    #if os(visionOS)
      return paywall.backgroundColor
    #elseif os(macOS)
      let appearance = PlatformApplication.sharedApplication?.effectiveAppearance
      if appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
        return paywall.darkBackgroundColor ?? paywall.backgroundColor
      }
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
  private lazy var refreshPaywallButton: PlatformButton = {
    ButtonFactory.make(
      imageNamed: "SuperwallKit_reload_paywall",
      target: self,
      action: #selector(reloadWebView)
    )
  }()

  /// A button that exits the paywall.
  private lazy var exitButton: PlatformButton = {
    ButtonFactory.make(
      imageNamed: "SuperwallKit_exit_paywall",
      target: self,
      action: #selector(forceClose)
    )
  }()

  #if !os(macOS)
  /// The push presentation animation transition delegate.
  private let transitionDelegate = PushTransitionDelegate()
  /// The popup presentation animation transition delegate.
  private let popupTransitionDelegate = PopupTransitionDelegate()
  #endif

  /// Defines whether the refresh alert view controller has been created.
  private var hasRefreshAlertController = false

  /// Cancellable observer.
  private var resignActiveObserver: AnyCancellable?

  private var presentationWillPrepare = true
  private var presentationDidFinishPrepare = false
  private var didCallDelegate = false

  /// `true` if there's a survey to complete and the paywall is displayed in a modal style.
  private var didDisableSwipeForSurvey = false

  #if !os(macOS)
  private var drawerDeviceCornerRadius: CGFloat?
  private var drawerCornerMaskLayer: CAShapeLayer?
  #endif

  /// Whether the survey was shown, not shown, or in a holdout. Defaults to not shown.
  private var surveyPresentationResult: SurveyPresentationResult = .noShow

  /// If the user matches an audience with an occurrence, this needs to be saved on
  /// paywall presentation.
  private var unsavedOccurrence: TriggerAudienceOccurrence?

  private var lastOpen: Date?

  #if os(macOS)
  /// From when the SDK starts presenting until the paywall appears: the span
  /// UIKit reports through `isBeingPresented`, which AppKit doesn't have.
  private var isMacPresentationInFlight = false

  /// Callers waiting in ``dismiss(animated:)`` for AppKit to finish.
  private var dismissalContinuations: [CheckedContinuation<Void, Never>] = []

  /// The dimmed backdrop behind a popup, which closes it when clicked.
  private var popupBackgroundView: NSView?
  #endif

  private struct PopupDimensions {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
  }

  private unowned let factory: Factory
  private unowned let storage: Storage
  private unowned let deviceHelper: DeviceHelper
  private unowned let webEntitlementRedeemer: WebEntitlementRedeemer
  private unowned let customCallbackRegistry: CustomCallbackRegistry
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
    network: Network,
    webView: SWWebView,
    webEntitlementRedeemer: WebEntitlementRedeemer,
    cache: PaywallViewControllerCache?,
    paywallArchiveManager: PaywallArchiveManager?,
    customCallbackRegistry: CustomCallbackRegistry
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
    self.introOfferTokenManager = IntroOfferTokenManager(network: network)
    self.webEntitlementRedeemer = webEntitlementRedeemer
    self.customCallbackRegistry = customCallbackRegistry

    presentationStyle = paywall.presentation.style
    super.init(nibName: nil, bundle: nil)
    syncCustomCallbackRegistration()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Registers or unregisters the delegate's custom callback handler with
  /// ``CustomCallbackRegistry`` so the paywall webview can invoke it.
  ///
  /// `register()` manages registration around its own present/dismiss lifecycle, so this
  /// path is the one that wires up handlers supplied via
  /// ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:onCustomCallback:)``.
  private var hasRegisteredCallback = false

  private func syncCustomCallbackRegistration() {
    if let handler = delegate?.onCustomCallback {
      customCallbackRegistry.register(
        paywallIdentifier: paywall.identifier,
        handler: handler
      )
      hasRegisteredCallback = true
    } else if hasRegisteredCallback {
      customCallbackRegistry.unregister(paywallIdentifier: paywall.identifier)
      hasRegisteredCallback = false
    }
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    configureUI()
    loadWebView()
    introOfferTokenManager.startObservingAppLifecycle()
  }

  deinit {
    introOfferTokenManager.stopObservingAppLifecycle()
    if hasRegisteredCallback {
      customCallbackRegistry.unregister(paywallIdentifier: paywall.identifier)
    }
  }

  private func configureUI() {
    #if !os(macOS)
    modalPresentationCapturesStatusBarAppearance = true
    #endif
    #if !os(visionOS) && !os(macOS)
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
    view.addSubview(exitButton)
    #if os(macOS)
    refreshPaywallButton.contentTintColor = loadingColor.withAlphaComponent(0.5)
    exitButton.contentTintColor = loadingColor.withAlphaComponent(0.5)
    // An NSView has no layout margins. The safe area keeps the buttons clear of
    // a window's title bar.
    let marginsGuide = view.safeAreaLayoutGuide
    #else
    refreshPaywallButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
    exitButton.imageView?.tintColor = loadingColor.withAlphaComponent(0.5)
    let marginsGuide = view.layoutMarginsGuide
    #endif

    NSLayoutConstraint.activate([
      refreshPaywallButton.topAnchor.constraint(
        equalTo: marginsGuide.topAnchor, constant: 17),
      refreshPaywallButton.trailingAnchor.constraint(
        equalTo: marginsGuide.trailingAnchor, constant: 0),
      refreshPaywallButton.widthAnchor.constraint(equalToConstant: 55),
      refreshPaywallButton.heightAnchor.constraint(equalToConstant: 55),

      exitButton.topAnchor.constraint(equalTo: marginsGuide.topAnchor, constant: 17),
      exitButton.leadingAnchor.constraint(
        equalTo: marginsGuide.leadingAnchor, constant: 0),
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
    await maybeRecoverPendingStripeCheckoutOnPaywallOpen()

    let demandScore = await deviceHelper.enrichment?.device["demandScore"].int
    let demandTier = await deviceHelper.enrichment?.device["demandTier"].string

    let paywallOpen = await InternalSuperwallEvent.PaywallOpen(
      paywallInfo: info,
      demandScore: demandScore,
      demandTier: demandTier
    )
    await Superwall.shared.track(paywallOpen)
  }

  nonisolated private func maybeRecoverPendingStripeCheckoutOnPaywallOpen() async {
    let shouldShowLoading =
      await webEntitlementRedeemer.shouldShowStripeRecoveryLoadingOnPaywallOpen()
    guard shouldShowLoading else {
      return
    }

    await MainActor.run {
      self.loadingState = .manualLoading
    }

    // If another poll is already in-flight (e.g. cold-launch init task),
    // wait for it to finish rather than returning early. This ensures
    // WE always clean up the spinner we set above.
    let redeemed = await webEntitlementRedeemer.pollOrWaitForActiveStripePoll()

    if !redeemed {
      await MainActor.run {
        if self.loadingState == .manualLoading {
          self.loadingState = .ready
        }
      }
    }
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
    webView.messageHandler.documentWillLoad()

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

    #if os(macOS)
    webView.isScrollEnabled = paywall.isScrollEnabled
    #else
    webView.scrollView.isScrollEnabled = paywall.isScrollEnabled
    #endif
  }

  func closeSafari(completion: (() -> Void)? = nil) {
    guard isSafariVCPresented else {
      completion?()
      return
    }

    // Check if it's a Safari VC or Checkout Web VC
    #if os(macOS)
      // Links open in the user's browser, so checkout is all there is to close.
      if let checkoutVC = presentedViewControllers?.first(where: { $0 is CheckoutWebViewController }) {
        // Mark as programmatic dismissal to prevent tracking transaction abandon
        isCheckoutDismissedProgrammatically = true
        dismiss(checkoutVC)
      }
      completion?()
    #elseif !os(visionOS)
      if let safariVC = presentedViewController as? SFSafariViewController {
        safariVC.dismiss(
          animated: true,
          completion: completion
        )
      } else if let checkoutVC = presentedViewController as? CheckoutWebViewController {
        // Mark as programmatic dismissal to prevent tracking transaction abandon
        isCheckoutDismissedProgrammatically = true
        checkoutVC.dismiss(
          animated: true,
          completion: completion
        )
      } else {
        completion?()
      }
    #else
      if let safariVC = presentedViewController as? SFSafariViewController {
        safariVC.dismiss(
          animated: true,
          completion: completion
        )
      } else {
        completion?()
      }
    #endif

    // Must set this manually because programmatically dismissing doesn't call
    // delegate methods where we set this.
    isSafariVCPresented = false
  }

  private func loadWebViewFromArchive(url: URL) {
    webView.loadFileURL(url, allowingReadAccessTo: url)
  }

  @objc private func reloadWebView() {
    webView.reload()
  }

  // MARK: - State Handling

  /// Reveals the web view content behind the spinner overlay when the web
  /// view finishes loading while a manual spinner (e.g. Stripe recovery) is
  /// active. Animates the shimmer away and fades in the web view, but keeps
  /// the spinner visible so the user knows a background operation is ongoing.
  func revealWebViewBehindSpinner() {
    guard shimmerView != nil else { return }
    showRefreshButtonAfterTimeout(false)
    PlatformView.animate(
      withDuration: 0.6,
      delay: 0.25,
      animations: {
        self.shimmerView?.alpha = 0.0
        self.webView.alpha = 1.0
        #if !os(macOS)
        self.webView.transform = .identity
        #endif
      },
      completion: { [weak self] _ in
        self?.shimmerView?.removeFromSuperview()
        self?.shimmerView = nil
      }
    )
  }

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
      PlatformView.springAnimate {
        self.webView.alpha = 0.0
        #if !os(macOS)
        self.webView.transform = CGAffineTransform.identity.translatedBy(x: 0, y: -10)
        #endif
      }
    case .ready:
      let spinnerDidShow = oldValue == .loadingPurchase || oldValue == .manualLoading
      let shimmerStillVisible = shimmerView != nil
      #if !os(macOS)
      // An NSView has no transform, so the web view fades in without the nudge.
      let translation = CGAffineTransform.identity.translatedBy(x: 0, y: 10)
      webView.transform = spinnerDidShow && !shimmerStillVisible ? .identity : translation
      #endif
      showRefreshButtonAfterTimeout(false)
      hideLoadingView()

      if !spinnerDidShow || shimmerStillVisible {
        PlatformView.animate(
          withDuration: 0.6,
          delay: 0.25,
          animations: {
            self.shimmerView?.alpha = 0.0
            self.webView.alpha = 1.0
            #if !os(macOS)
            self.webView.transform = .identity
            #endif
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

    let shimmerSuperview: PlatformView
    switch presentationStyle {
    case .popup:
      // For popup style, use the popup container
      shimmerSuperview = popupContainerView ?? view

      // Apply the same corner radius as the popup to the shimmer view
      if let dimensions = getPopupDimensions() {
        #if os(macOS)
        shimmerView.layer?.cornerRadius = dimensions.cornerRadius
        #else
        shimmerView.layer.cornerRadius = dimensions.cornerRadius
        shimmerView.layer.masksToBounds = true
        #endif
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

        #if !os(macOS)
        // On macOS they're already in front: they're added after the web view,
        // and the shimmer goes in below it.
        self.view.bringSubviewToFront(self.refreshPaywallButton)
        self.view.bringSubviewToFront(self.exitButton)
        #endif

        self.refreshPaywallButton.isHidden = false
        self.refreshPaywallButton.alpha = 0.0
        self.exitButton.isHidden = false
        self.exitButton.alpha = 0.0

        PlatformView.springAnimate(withDuration: 2) {
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
    PlatformView.springAnimate(
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

  /// Claims the view controller for a request: binds the request and applies
  /// the paywall resolved for it, so the placement, experiment and products
  /// reported for this presentation all come from the same request.
  ///
  /// A view controller that's on screen stays with the request that put it
  /// there, so a claim made while it's active is ignored.
  func set(
    request: PresentationRequest,
    paywall: Paywall,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    unsavedOccurrence: TriggerAudienceOccurrence?
  ) {
    let claim = Claim(
      request: request,
      paywall: paywall,
      paywallStatePublisher: paywallStatePublisher,
      unsavedOccurrence: unsavedOccurrence
    )
    let isHandedOut: Bool
    if case .getPaywall = request.flags.type {
      isHandedOut = true
    } else {
      isHandedOut = false
    }

    if isActive {
      // The app still gets this view controller back from `getPaywall`, so
      // keep its claim for when the app shows it after the current
      // presentation ends.
      if isHandedOut {
        handedOutClaim = claim
        handedOutClaimNeedsRestoring = true
      }
      return
    }

    apply(claim)
    isPresentedBySDK = false

    if isHandedOut {
      handedOutClaim = claim
      handedOutClaimNeedsRestoring = false
    } else if handedOutClaim != nil {
      handedOutClaimNeedsRestoring = true
    }
  }

  /// Applies a claim. Returns whether it started a web view load.
  @discardableResult
  private func apply(_ claim: Claim) -> Bool {
    // Install the claim's delegate and request first, so anything the
    // reload below announces goes to the claim that owns it.
    delegate = claim.request.flags.type.getPaywallVcDelegateAdapter()
    request = claim.request
    if claim.paywallStatePublisher == nil {
      // The previous one completed when the paywall was last dismissed.
      claim.paywallStatePublisher = PassthroughSubject()
    }
    paywallStateSubject = claim.paywallStatePublisher
    unsavedOccurrence = claim.unsavedOccurrence
    currentClaim = claim

    if claim.paywall.cacheKey == paywall.cacheKey {
      paywall.update(from: claim.paywall)
      return false
    }
    // The request resolved a different version of the paywall from the one
    // loaded, so show that version rather than only its products.
    paywall = claim.paywall
    loadWebView()
    return true
  }

  #if !os(macOS)
  func present(
    on presenter: UIViewController,
    request: PresentationRequest,
    paywall: Paywall,
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
      paywall: paywall,
      paywallStatePublisher: paywallStatePublisher,
      unsavedOccurrence: unsavedOccurrence
    )

    setPresentationStyle(withOverride: presentationStyleOverride)
    isPresentedBySDK = true

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
        if #available(iOS 16.0, macOS 13.0, *),
          UIDevice.current.userInterfaceIdiom == .phone {
          let heightRatio = height / 100
          sheetPresentationController?.detents = [
            .custom { context in
              return heightRatio * context.maximumDetentValue
            }
          ]
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

  #if !os(visionOS)
    @available(iOS 16.0, macOS 13.0, *)
    private func updateDrawerCornerMaskIfNeeded() {
      guard
        UIDevice.current.userInterfaceIdiom == .phone,
        case .drawer(_, let cornerRadius) = presentationStyle,
        let sheet = sheetPresentationController,
        let presentedView = sheet.presentedView ?? view.superview
      else {
        return
      }

      let targetView: UIView
      if presentedView.layer.cornerRadius > 0 {
        targetView = presentedView
      } else if let superview = presentedView.superview,
        superview.layer.cornerRadius > 0 {
        targetView = superview
      } else {
        targetView = presentedView
      }

      let systemRadius = targetView.layer.cornerRadius
      if drawerDeviceCornerRadius == nil || drawerDeviceCornerRadius == 0,
        systemRadius > 0 {
        drawerDeviceCornerRadius = systemRadius
      }
      let bottomRadius = drawerDeviceCornerRadius ?? systemRadius
      applyDrawerCornerMask(
        to: targetView,
        topRadius: CGFloat(cornerRadius),
        bottomRadius: bottomRadius
      )
    }

    private func applyDrawerCornerMask(
      to targetView: UIView,
      topRadius: CGFloat,
      bottomRadius: CGFloat
    ) {
      let bounds = targetView.bounds
      guard
        bounds.width > 0,
        bounds.height > 0
      else {
        return
      }

      let maxRadius = min(bounds.width, bounds.height) / 2
      let clampedTop = min(max(0, topRadius), maxRadius)
      let clampedBottom = min(max(0, bottomRadius), maxRadius)

      // Build a path with independent top and bottom corner radii.
      let path = UIBezierPath()
      path.move(to: CGPoint(x: bounds.minX + clampedTop, y: bounds.minY))
      path.addLine(to: CGPoint(x: bounds.maxX - clampedTop, y: bounds.minY))
      path.addArc(
        withCenter: CGPoint(x: bounds.maxX - clampedTop, y: bounds.minY + clampedTop),
        radius: clampedTop,
        startAngle: -.pi / 2,
        endAngle: 0,
        clockwise: true
      )
      path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY - clampedBottom))
      path.addArc(
        withCenter: CGPoint(x: bounds.maxX - clampedBottom, y: bounds.maxY - clampedBottom),
        radius: clampedBottom,
        startAngle: 0,
        endAngle: .pi / 2,
        clockwise: true
      )
      path.addLine(to: CGPoint(x: bounds.minX + clampedBottom, y: bounds.maxY))
      path.addArc(
        withCenter: CGPoint(x: bounds.minX + clampedBottom, y: bounds.maxY - clampedBottom),
        radius: clampedBottom,
        startAngle: .pi / 2,
        endAngle: .pi,
        clockwise: true
      )
      path.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY + clampedTop))
      path.addArc(
        withCenter: CGPoint(x: bounds.minX + clampedTop, y: bounds.minY + clampedTop),
        radius: clampedTop,
        startAngle: .pi,
        endAngle: 3 * .pi / 2,
        clockwise: true
      )
      path.close()

      let maskLayer = drawerCornerMaskLayer ?? CAShapeLayer()
      maskLayer.frame = bounds
      maskLayer.path = path.cgPath
      targetView.layer.mask = maskLayer
      drawerCornerMaskLayer = maskLayer
      if targetView.layer.cornerRadius != 0 {
        targetView.layer.cornerRadius = 0
      }
    }
  #endif
  #endif

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

  #if !os(macOS)
  private func setupPopupBackground() {
    // Set transparent background for the main view
    view.backgroundColor = .clear

    // Create a semi-transparent background view matching iOS alert style
    let backgroundView = UIView()
    backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.alpha = 0.0  // Start transparent for animation
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
    PlatformView.animate(withDuration: 0.3) {
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
    let popupWidthConstraint = containerView.widthAnchor.constraint(
      equalToConstant: dimensions.width)
    self.popupWidthConstraint = popupWidthConstraint
    let popupHeightConstraint = containerView.heightAnchor.constraint(
      equalToConstant: dimensions.height)
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
    PlatformView.animate(
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
  #endif
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
#if !os(macOS)
extension PaywallViewController: UIAdaptivePresentationControllerDelegate {
  public func presentationControllerDidAttemptToDismiss(
    _ presentationController: UIPresentationController
  ) {
    dismiss(
      result: .declined,
      closeReason: .manualClose
    )
  }

  public func presentationControllerDidDismiss(
    _ presentationController: UIPresentationController
  ) {
    // Guard against double-dismiss: if didAttemptToDismiss already
    // triggered our dismiss(), closeReason will already be set.
    guard paywall.closeReason == .none else {
      return
    }
    dismiss(
      result: .declined,
      closeReason: .manualClose
    )
  }
}
#endif

extension PaywallViewController {
  /// Marks that a redeem succeeded while the checkout web view is open.
  /// Cancels any pending transaction abandon tracking.
  func markRedeemInitiated() {
    didRedeemSucceedDuringCheckout = true
    transactionAbandonWorkItem?.cancel()
    transactionAbandonWorkItem = nil
    #if !os(visionOS)
      // Mark checkout as having handled redemption to prevent duplicate navigations
      currentCheckoutVC?.hasHandledRedemption = true
    #endif
  }
}

// MARK: - PaywallMessageHandlerDelegate
extension PaywallViewController: PaywallMessageHandlerDelegate {
  func openPaymentSheet(_ url: URL) {
    #if !os(visionOS)
      // Reset flags when opening checkout
      didRedeemSucceedDuringCheckout = false
      isCheckoutDismissedProgrammatically = false
      didReceiveStripeCheckoutAbandonMessage = false
      transactionAbandonWorkItem?.cancel()
      transactionAbandonWorkItem = nil

      let checkoutVC = CheckoutWebViewController(url: url)
      // Store reference to communicate redemption state
      self.currentCheckoutVC = checkoutVC
      checkoutVC.onDismiss = { [weak self] in
        guard let self = self else { return }
        self.isSafariVCPresented = false

        // Set loadingState to ready unless we programmatically dismissed
        // (programmatic dismissal happens when redemption starts, which sets manualLoading)
        if !self.isCheckoutDismissedProgrammatically {
          self.loadingState = .ready
        }

        // Only track abandon if:
        // 1. Redeem did NOT succeed
        // 2. Dismissal was NOT programmatic (user dismissed it)
        // 3. No stripe checkout abandon message was received
        if !self.didRedeemSucceedDuringCheckout,
          !self.isCheckoutDismissedProgrammatically,
          !self.didReceiveStripeCheckoutAbandonMessage {
          let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            Task {
              let event = InternalSuperwallEvent.Transaction(
                state: .abandon(StoreProduct.blank()),
                paywallInfo: self.info,
                product: nil,
                transaction: nil,
                source: .internal,
                isObserved: false,
                storeKitVersion: nil,
                store: .stripe
              )
              await Superwall.shared.track(event)
            }
          }
          self.transactionAbandonWorkItem = workItem
          DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0, execute: workItem)
        }
        // Reset flags after handling
        self.didRedeemSucceedDuringCheckout = false
        self.isCheckoutDismissedProgrammatically = false
        self.didReceiveStripeCheckoutAbandonMessage = false
      }

      #if os(macOS)
      self.isSafariVCPresented = true
      loadingState = .loadingPurchase
      presentAsSheet(checkoutVC)
      #else
      checkoutVC.modalPresentationStyle = .pageSheet
      if let sheet = checkoutVC.sheetPresentationController {
        sheet.detents = [.medium(), .large()]
        sheet.prefersGrabberVisible = true
        // sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        sheet.prefersEdgeAttachedInCompactHeight = true
        sheet.preferredCornerRadius = 62
      }
      self.isSafariVCPresented = true
      loadingState = .loadingPurchase
      present(checkoutVC, animated: true)
      #endif
    #endif
  }

  func handleStripeCheckoutSubmit(checkoutContextId: String, productId: String) {
    enqueueStripeCheckoutTask { paywall in
      await paywall.webEntitlementRedeemer.registerStripeCheckoutSubmit(
        contextId: checkoutContextId,
        productId: productId
      )
    }
  }

  func handleStripeCheckoutComplete(
    checkoutContextId: String,
    productId: String,
    shouldDismiss: Bool?
  ) {
    didReceiveStripeCheckoutAbandonMessage = true
    loadingState = .manualLoading
    closeSafari()

    // A paywall that says whether to dismiss wants the purchase finished
    // like an App Store purchase; one that doesn't gets the legacy restore.
    let completion: StripeCheckoutCompletion = shouldDismiss.map {
      .purchase(productId: productId, shouldDismiss: $0)
    } ?? .restore

    enqueueStripeCheckoutTask { paywall in
      await paywall.webEntitlementRedeemer.handleStripeCheckoutComplete(
        contextId: checkoutContextId,
        productId: productId,
        completion: completion
      )
    }
  }

  func handleStripeCheckoutAbandon(checkoutContextId: String, productId: String) {
    didReceiveStripeCheckoutAbandonMessage = true
    transactionAbandonWorkItem?.cancel()
    transactionAbandonWorkItem = nil

    enqueueStripeCheckoutTask { paywall in
      await paywall.webEntitlementRedeemer.handleStripeCheckoutAbandon(productId: productId)
    }
  }

  private func enqueueStripeCheckoutTask(
    _ operation: @escaping (PaywallViewController) async -> Void
  ) {
    // Queue the callback behind any already in flight and return. The closure
    // stays on the main actor so the callbacks run where they always have.
    stripeCheckoutCoordinator.enqueue { @MainActor [weak self] in
      guard let self else {
        return
      }
      await operation(self)
    }
  }

  func eventDidOccur(_ paywallEvent: PaywallWebEvent) {
    Task {
      await eventDelegate?.eventDidOccur(
        paywallEvent,
        on: self
      )
    }
  }

  func presentSafariInApp(_ url: URL) {
    #if os(macOS)
    // There's no in-app browser on macOS, so the link opens in the user's.
    presentSafariExternal(url, drawsWaitingScreen: false, isTeleport: false)
    #else
    guard let sharedApplication = PlatformApplication.sharedApplication else {
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
    #endif
  }

  func presentSafariExternal(_ url: URL, drawsWaitingScreen: Bool, isTeleport: Bool) {
    // Only a teleport needs the cover. It's there even when no waiting screen is drawn, so the
    // page still hears the return link.
    guard isTeleport else {
      openExternally(url)
      return
    }
    teleportReturnCover.leave(drawingWaitingScreen: drawsWaitingScreen) { [weak self] in
      self?.openExternally(url)
    }
  }

  func startTeleportWatch(_ watch: TeleportReturnCover.Watch) {
    teleportReturnCover.startWatching(watch)
  }

  func endTeleportWatch() {
    existingTeleportReturnCover?.stopWatching()
  }

  private var teleportReturnCover: TeleportReturnCover {
    if let existingTeleportReturnCover {
      return existingTeleportReturnCover
    }
    let cover = TeleportReturnCover(view: view, webView: webView)
    existingTeleportReturnCover = cover
    return cover
  }

  private func openExternally(_ url: URL) {
    guard let sharedApplication = PlatformApplication.sharedApplication else {
      return
    }
    sharedApplication.open(url)
  }

  func openDeepLink(_ url: URL, shouldDismiss: Bool) {
    let openUrl = { [weak self] in
      self?.eventDidOccur(.openedDeepLink(url: url))
      guard let sharedApplication = PlatformApplication.sharedApplication else {
        return
      }
      sharedApplication.open(url)
    }

    if shouldDismiss {
      dismiss(
        result: .declined,
        closeReason: .systemLogic,
        completion: openUrl
      )
    } else {
      openUrl()
    }
  }

  func requestReview(type: ReviewType) {
    switch type {
    case .inApp:
      #if os(macOS)
      if #available(macOS 13.0, *) {
        AppStore.requestReview(in: self)
      } else {
        SKStoreReviewController.requestReview()
      }
      #else
      if let scene = view.window?.windowScene ?? PlatformApplication.sharedApplication?.activeWindowScene {
        #if os(visionOS)
          AppStore.requestReview(in: scene)
        #else
          if #available(iOS 16.0, macOS 13.0, *) {
            AppStore.requestReview(in: scene)
          } else {
            SKStoreReviewController.requestReview(in: scene)
          }
        #endif
      }
      #endif
      trackReviewRequest(type: .inApp)
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
          message:
            "Unable to open external review URL. Please enter your Apple App ID on the Superwall dashboard."
        )
        return
      }

      if let url = URL(string: "https://apps.apple.com/app/id\(appId)?action=write-review") {
        PlatformApplication.sharedApplication?.open(url)
        trackReviewRequest(type: .external)
      }
    }
  }

  private func trackReviewRequest(type: ReviewType) {
    Task {
      let count = await deviceHelper.reviewRequestsTotal() + 1
      let reviewRequestEvent = InternalSuperwallEvent.ReviewRequested(
        count: count,
        type: type
      )
      await Superwall.shared.track(reviewRequestEvent)
    }
  }
}

// MARK: - View Lifecycle
extension PaywallViewController {
  #if !os(macOS)
  override public func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    #if !os(visionOS)
      if #available(iOS 16.0, macOS 13.0, *) {
        updateDrawerCornerMaskIfNeeded()
      }
    #endif
  }

  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    handleViewWillAppear()
  }
  #endif

  private func handleViewWillAppear() {
    // The app is showing a view controller it got from `getPaywall`, and
    // another request has claimed it since. Report the app's placement. Only
    // on an appearance that starts a presentation: `viewWillAppear` also fires
    // when the paywall is already on screen, such as after Safari closes.
    var didStartLoadForClaim = false
    if presentationWillPrepare,
      !isPresentedBySDK,
      handedOutClaimNeedsRestoring,
      let claim = handedOutClaim {
      didStartLoadForClaim = apply(claim)
      handedOutClaimNeedsRestoring = false
    }
    cache?.activePaywallVcKey = cacheKey

    if isSafariVCPresented {
      return
    }

    if !deviceHelper.isMac {
      webView.setAllMediaPlaybackSuspended(false)
    }

    if webView.loadingHandler.didFailToLoad,
      !didStartLoadForClaim {
      loadWebView()
    }

    presentationWillBegin()
  }

  #if !os(macOS)
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
  #endif

  /// Prepares the view controller for presentation. Only called once per presentation.
  private func presentationWillBegin() {
    guard presentationWillPrepare else {
      return
    }

    // Fetch intro offer eligibility tokens for SK2 purchases on iOS 18.2+
    fetchIntroOfferTokens()

    #if !os(macOS)
    // A Mac sheet has no swipe to block: Escape closes it through `dismiss`,
    // which shows the survey.
    switch presentationStyle {
    case .modal, .drawer:
      let shouldShowSurvey = willShowSurvey
      presentationController?.delegate = self
      if shouldShowSurvey {
        didDisableSwipeForSurvey = true
        isModalInPresentation = true
      }
    default:
      if willShowSurvey {
        didDisableSwipeForSurvey = true
        presentationController?.delegate = self
        isModalInPresentation = true
      }
    }
    #endif
    addShimmerView(onPresent: true)

    view.alpha = 1.0
    #if !os(macOS)
    view.transform = .identity
    #endif

    didCallDelegate = false
    paywall.closeReason = .none
    // A purchase belongs to the presentation it was made in. It's cleared here rather than when
    // the view disappears: a sheet swiped away disappears before its close is reported.
    completedPurchaseProduct = nil
    Superwall.shared.dependencyContainer.delegateAdapter.willPresentPaywall(withInfo: info)

    #if os(macOS)
    webView.evaluateJavaScript("window.scrollTo(0, 0)")
    #else
    webView.scrollView.contentOffset = CGPoint.zero
    #endif
    if loadingState == .ready {
      webView.messageHandler.handle(.templateParamsAndUserAttributes)
    }

    presentationWillPrepare = false
  }

  // MARK: - Intro Offer Token Management

  /// Fetches intro offer eligibility tokens if configured for this paywall
  private func fetchIntroOfferTokens() {
    Task {
      await introOfferTokenManager.fetchTokens(
        introOfferEligibility: paywall.introOfferEligibility,
        paywallId: paywall.identifier,
        productIds: paywall.productIdsWithIntroOffers,
        appTransactionId: ReceiptManager.appTransactionId
      )
    }
  }

  #if !os(macOS)
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    presentationDidFinish()
  }
  #endif

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
      currentClaim?.unsavedOccurrence = nil
    }
    isPresented = true
    Superwall.shared.dependencyContainer.delegateAdapter.didPresentPaywall(withInfo: info)
    Task {
      await trackOpen()
    }
    GameControllerManager.shared.setDelegate(self)
    presentationDidFinishPrepare = true
  }

  #if !os(macOS)
  override public func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    handleViewWillDisappear()
  }

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    handleViewDidDisappear()
  }
  #endif

  private func handleViewWillDisappear() {
    guard isPresented else {
      return
    }
    if isSafariVCPresented {
      return
    }

    willDismiss()
  }

  private func handleViewDidDisappear() {
    existingTeleportReturnCover?.reset()
    guard isPresented else {
      return
    }
    if isSafariVCPresented {
      return
    }
    Task {
      await trackClose()
    }

    if !deviceHelper.isMac {
      webView.setAllMediaPlaybackSuspended(true)
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

  /// Records a completed purchase before the paywall hears `transaction_complete`.
  func markPurchaseCompleted(_ product: StoreProduct) {
    completedPurchaseProduct = product
  }

  /// The result a dismissal reports: a decline after a completed purchase is a purchase. A close
  /// to show the next paywall stays as it is, so that paywall keeps the presentation's state.
  func resolvedDismissal(
    result: PaywallResult,
    closeReason: PaywallCloseReason
  ) -> (result: PaywallResult, closeReason: PaywallCloseReason) {
    if closeReason == .forNextPaywall {
      return (result, closeReason)
    }
    if result == .declined, let product = completedPurchaseProduct {
      return (.purchased(product), .systemLogic)
    }
    return (result, closeReason)
  }

  func dismiss(
    result: PaywallResult,
    closeReason: PaywallCloseReason,
    completion: (() -> Void)? = nil
  ) {
    let (result, closeReason) = resolvedDismissal(result: result, closeReason: closeReason)
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
    let result = paywallResult ?? .declined
    paywallStateSubject?.send(.willDismiss(info, result))

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

    #if !os(macOS)
    if didDisableSwipeForSurvey {
      presentationController?.delegate = nil
      isModalInPresentation = false
      didDisableSwipeForSurvey = false
    }
    #endif

    paywallResult = nil
    cache?.activePaywallVcKey = nil
    isPresented = false
    isPresentedBySDK = false

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
      currentClaim?.paywallStatePublisher = nil
    }

    Superwall.shared.dependencyContainer.delegateAdapter.didDismissPaywall(withInfo: info)
  }
}

#if !os(visionOS) && !os(macOS)
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

#if os(macOS)
// MARK: - AppKit
extension PaywallViewController {
  /// How a paywall is put on screen on macOS.
  private enum MacPresentation {
    /// A sheet on the presenter's window, for the modal and drawer styles.
    case sheet(CGSize)
    /// Over the whole of the presenter's view.
    case overlay(PaywallOverlayAnimator.Transition)
  }

  override public func loadView() {
    view = NSView(frame: NSRect(origin: .zero, size: PaywallSheetSize.preferred))
  }

  override public func viewWillAppear() {
    super.viewWillAppear()
    handleViewWillAppear()
  }

  override public func viewDidAppear() {
    super.viewDidAppear()
    isMacPresentationInFlight = false
    presentationDidFinish()
  }

  override public func viewWillDisappear() {
    super.viewWillDisappear()
    handleViewWillDisappear()
  }

  override public func viewDidDisappear() {
    super.viewDidDisappear()
    handleViewDidDisappear()
    resumeDismissalContinuations()
  }

  /// Whether the SDK has started presenting the paywall and it hasn't appeared yet.
  var isBeingPresented: Bool {
    return isMacPresentationInFlight
  }

  /// Escape closes a paywall shown as a sheet, as swiping one down does on iOS.
  ///
  /// Like the swipe, it's a manual close, so a survey can show first. Other
  /// styles close only from the paywall's own button, as on iOS.
  override public func cancelOperation(_ sender: Any?) {
    guard
      isPresented,
      view.window?.sheetParent != nil
    else {
      super.cancelOperation(sender)
      return
    }
    dismiss(
      result: .declined,
      closeReason: .manualClose
    )
  }

  func present(
    on presenter: NSViewController,
    request: PresentationRequest,
    paywall: Paywall,
    unsavedOccurrence: TriggerAudienceOccurrence?,
    presentationStyleOverride: PaywallPresentationStyle?,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    completion: @escaping (Bool) -> Void
  ) {
    if Superwall.shared.isPaywallPresented
      || presenter is PaywallViewController
      || isBeingPresented
      || presentingViewController != nil {
      return completion(false)
    }

    set(
      request: request,
      paywall: paywall,
      paywallStatePublisher: paywallStatePublisher,
      unsavedOccurrence: unsavedOccurrence
    )

    setPresentationStyle(withOverride: presentationStyleOverride)
    isPresentedBySDK = true
    isMacPresentationInFlight = true

    switch macPresentation(on: presenter) {
    case .sheet(let size):
      preferredContentSize = size
      presenter.presentAsSheet(self)
    case .overlay(let transition):
      overlayHost(over: presenter).present(
        self,
        animator: PaywallOverlayAnimator(transition: transition)
      )
    }
    completion(true)
  }

  /// The view controller an overlay is presented on: the root of a window the
  /// SDK owns, never one of the app's own.
  ///
  /// That's the window the SDK made because the app had none, or a new
  /// ``PaywallOverlayWindow`` over the presenter's window. Either way it's kept
  /// as the presenting window, which is closed once the paywall is dismissed.
  private func overlayHost(over presenter: NSViewController) -> NSViewController {
    let presentationItems = Superwall.shared.presentationItems
    if let window = presenter.view.window as? PaywallHostWindow {
      return window.host
    }
    guard let parentWindow = presenter.view.window else {
      return presenter
    }
    let overlayWindow = PaywallOverlayWindow(over: parentWindow)
    presentationItems.window = overlayWindow
    return overlayWindow.host
  }

  private func macPresentation(on presenter: NSViewController) -> MacPresentation {
    let window = presenter.view.window
    // The SDK made a window just for this paywall, so the paywall fills it.
    if window is PaywallHostWindow {
      return .overlay(.none)
    }

    switch presentationStyle {
    case .modal,
      .none:
      return .sheet(PaywallSheetSize.fitting(window))
    case .drawer(let height, _):
      var size = PaywallSheetSize.fitting(window)
      size.height = max(320, size.height * CGFloat(height / 100))
      return .sheet(size)
    case .fullscreen:
      return .overlay(presentationIsAnimated ? .slideUp : .none)
    case .fullscreenNoAnimation:
      return .overlay(.none)
    case .push:
      return .overlay(.slideFromTrailingEdge)
    case .popup:
      return .overlay(.fade)
    }
  }

  private func setPresentationStyle(withOverride override: PaywallPresentationStyle?) {
    if let override = override,
      override != .none {
      presentationStyle = override
    } else {
      presentationStyle = paywall.presentation.style
    }

    // A cached controller can move between popup and full-window presentations.
    // Remove it before reparenting so constraints to its old ancestor are removed.
    _ = view
    webView.removeFromSuperview()
    shimmerView?.removeFromSuperview()
    shimmerView = nil
    popupContainerView?.removeFromSuperview()
    popupBackgroundView?.removeFromSuperview()
    popupContainerView = nil
    popupBackgroundView = nil
    webView.layer?.cornerRadius = 0
    if case .popup = presentationStyle {
      setupPopupBackground()
    } else {
      view.backgroundColor = backgroundColor
      view.addSubview(webView, positioned: .below, relativeTo: refreshPaywallButton)
      NSLayoutConstraint.activate([
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        webView.topAnchor.constraint(equalTo: view.topAnchor),
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      ])
    }
  }

  /// Lays the paywall out as a card over a dimmed backdrop, sized as a share
  /// of the view so it follows the window as it resizes.
  private func setupPopupBackground() {
    guard case let .popup(height, width, cornerRadius) = presentationStyle else {
      return
    }
    view.backgroundColor = .clear

    // A view controller the SDK caches can show as a popup more than once.
    if let containerView = popupContainerView {
      containerView.alpha = 1
      popupBackgroundView?.alpha = 1
      return
    }

    let backgroundView = NSView()
    backgroundView.backgroundColor = NSColor.black.withAlphaComponent(0.4)
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.addGestureRecognizer(
      NSClickGestureRecognizer(target: self, action: #selector(backgroundClicked))
    )
    view.addSubview(backgroundView, positioned: .below, relativeTo: nil)
    popupBackgroundView = backgroundView

    let containerView = NSView()
    containerView.translatesAutoresizingMaskIntoConstraints = false
    containerView.wantsLayer = true
    containerView.layer?.cornerRadius = CGFloat(cornerRadius)
    containerView.layer?.masksToBounds = false
    containerView.shadow = {
      let shadow = NSShadow()
      shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
      shadow.shadowOffset = NSSize(width: 0, height: -2)
      shadow.shadowBlurRadius = 10
      return shadow
    }()
    view.addSubview(containerView)
    popupContainerView = containerView

    webView.wantsLayer = true
    webView.layer?.cornerRadius = CGFloat(cornerRadius)
    webView.layer?.masksToBounds = true
    webView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(webView)

    NSLayoutConstraint.activate([
      backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      containerView.widthAnchor.constraint(
        equalTo: view.widthAnchor,
        multiplier: CGFloat(width / 100)
      ),
      containerView.heightAnchor.constraint(
        equalTo: view.heightAnchor,
        multiplier: CGFloat(height / 100)
      ),

      webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      webView.topAnchor.constraint(equalTo: containerView.topAnchor),
      webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ])
  }

  @objc private func backgroundClicked() {
    isCustomBackgroundDismissal = true
    PlatformView.animate(
      withDuration: 0.25,
      animations: {
        self.popupContainerView?.alpha = 0
        self.popupBackgroundView?.alpha = 0
      },
      completion: { [weak self] _ in
        self?.isCustomBackgroundDismissal = false
        self?.dismiss(result: .declined, closeReason: .manualClose)
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
    // A window shows one sheet at a time.
    guard
      presentedViewControllers?.isEmpty != false,
      view.window?.attachedSheet == nil
    else {
      return
    }

    var model: [Action] = []
    if let actionTitle = actionTitle,
      let action = action {
      model = [Action(title: actionTitle, call: action)]
    }

    AlertControllerFactory.present(
      title: title,
      message: message,
      closeActionTitle: closeActionTitle,
      actions: model,
      onClose: onClose,
      on: self
    )
    loadingState = .ready
  }

  /// Dismisses the paywall and waits for it to leave the screen.
  ///
  /// AppKit has no completion handler for this, so it waits for
  /// `viewDidDisappear`, with a fallback in case the view never was on screen.
  @MainActor
  func dismiss(animated: Bool) async {
    guard let presenter = presentingViewController else {
      return
    }
    await withCheckedContinuation { continuation in
      dismissalContinuations.append(continuation)
      presenter.dismiss(self)
      DispatchQueue.main.asyncAfter(
        deadline: .now() + PaywallOverlayAnimator.duration + 1
      ) { [weak self] in
        self?.resumeDismissalContinuations()
      }
    }
  }

  private func resumeDismissalContinuations() {
    let continuations = dismissalContinuations
    dismissalContinuations = []
    continuations.forEach { $0.resume() }
  }
}
#endif
