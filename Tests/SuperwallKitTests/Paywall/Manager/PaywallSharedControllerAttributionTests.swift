//
//  PaywallSharedControllerAttributionTests.swift
//  SuperwallKitTests
//

// swiftlint:disable all

import Foundation
import Testing
import Combine
import UIKit
@testable import SuperwallKit

/// Lets a test say whether the view controller is on screen, and records
/// whether the web view was asked to load.
private final class ActivePaywallViewController: PaywallViewController {
  var isOnScreen = false
  var didLoadWebView: Bool { loadWebViewCount > 0 }
  var loadWebViewCount = 0
  /// The delegate installed at the moment a load was asked for.
  var delegateAtLoad: PaywallViewControllerDelegateAdapter?

  override var isActive: Bool { isOnScreen }

  override func loadWebView() {
    loadWebViewCount += 1
    delegateAtLoad = delegate
  }
}

/// Stands in for the view controller UIKit would present from: the SDK's
/// `present` only needs the presenter to say the presentation finished.
private final class CompletingPresenter: UIViewController {
  var presented: UIViewController?

  override func present(
    _ viewControllerToPresent: UIViewController,
    animated: Bool,
    completion: (() -> Void)? = nil
  ) {
    presented = viewControllerToPresent
    completion?()
  }
}

/// Counts occurrence saves instead of writing to Core Data.
private final class OccurrenceCountingCoreDataManager: CoreDataManager {
  var savedOccurrences = 0

  init() {
    super.init(coreDataStack: CoreDataStackMock())
  }

  override func save(
    triggerAudienceOccurrence audienceOccurence: TriggerAudienceOccurrence,
    completion: ((ManagedTriggerRuleOccurrence) -> Void)? = nil
  ) {
    savedOccurrences += 1
  }
}

/// Two campaigns share one paywall, so both requests get the one cached view
/// controller. Whatever a request reports for its presentation must all come
/// from that request, and a presentation that's on screen can't be changed by
/// another request.
@MainActor
struct PaywallSharedControllerAttributionTests {
  private let dependencyContainer = DependencyContainer()

  /// The view controller only holds its storage and dependencies unowned, and
  /// showing it starts tracking tasks that outlive the test, so anything it
  /// depends on must live for the rest of the process.
  private static var retained: [AnyObject] = []

  private func paywall(
    experimentId: String,
    variantId: String,
    source: String
  ) -> Paywall {
    var paywall = Paywall.stub()
    paywall.experiment = Experiment(
      id: experimentId,
      groupId: "group",
      variant: .init(id: variantId, type: .treatment, paywallId: paywall.identifier)
    )
    paywall.presentationSourceType = source
    return paywall
  }

  private var sessionStartPaywall: Paywall {
    paywall(experimentId: "180872", variantId: "632038", source: "implicit")
  }

  private var campaignPaywall: Paywall {
    paywall(experimentId: "181395", variantId: "633524", source: "register")
  }

  private var embeddedPaywall: Paywall {
    paywall(experimentId: "166736", variantId: "634019", source: "getPaywall")
  }

  private func request(
    placement: String,
    type: PresentationRequestType = .presentation
  ) -> PresentationRequest {
    dependencyContainer.makePresentationRequest(
      .implicitTrigger(PlacementData(name: placement, parameters: [:], createdAt: Date())),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: type
    )
  }

  private var getPaywallType: PresentationRequestType {
    .getPaywall(PaywallViewControllerDelegateAdapter(swiftDelegate: nil, objcDelegate: nil))
  }

  private func cacheKey(for paywall: Paywall) -> String {
    PaywallCacheLogic.key(
      identifier: paywall.identifier,
      locale: dependencyContainer.deviceHelper.localeIdentifier
    )
  }

  private func claim(
    _ viewController: PaywallViewController,
    placement: String,
    paywall: Paywall,
    type: PresentationRequestType = .presentation,
    unsavedOccurrence: TriggerAudienceOccurrence? = nil,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never> = .init()
  ) {
    viewController.set(
      request: request(placement: placement, type: type),
      paywall: paywall,
      paywallStatePublisher: paywallStatePublisher,
      unsavedOccurrence: unsavedOccurrence
    )
  }

  /// Puts a view controller for `paywall` in the cache, claimed by `placement`.
  private func cachedViewController(
    for paywall: Paywall,
    placement: String,
    storage: Storage? = nil
  ) -> ActivePaywallViewController {
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let cache = dependencyContainer.paywallManager!.cache
    let viewController = ActivePaywallViewController(
      paywall: paywall,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: storage ?? dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: cache,
      paywallArchiveManager: nil,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    cache.save(viewController, forKey: cacheKey(for: paywall))
    claim(viewController, placement: placement, paywall: paywall)
    return viewController
  }

  /// Runs the appearance callbacks the way UIKit does when the app shows the view controller.
  private func show(_ viewController: PaywallViewController) {
    Self.retained.append(dependencyContainer)
    viewController.viewWillAppear(false)
    viewController.viewDidAppear(false)
  }

  private func hide(_ viewController: PaywallViewController) {
    viewController.viewWillDisappear(false)
    viewController.viewDidDisappear(false)
  }

  private func expectSessionStartAttribution(_ info: PaywallInfo) {
    #expect(info.presentedByPlacementWithName == "session_start")
    #expect(info.experiment?.id == "180872")
    #expect(info.experiment?.variant.id == "632038")
    #expect(info.presentationSourceType == "implicit")
  }

  private func expectEmbeddedAttribution(_ info: PaywallInfo) {
    #expect(info.presentedByPlacementWithName == "embedded")
    #expect(info.experiment?.id == "166736")
    #expect(info.experiment?.variant.id == "634019")
    #expect(info.presentationSourceType == "getPaywall")
  }

  // MARK: - Claiming

  @Test
  func claimAppliesTheRequestsPaywall() {
    let viewController = cachedViewController(for: sessionStartPaywall, placement: "session_start")

    claim(viewController, placement: "campaign_trigger", paywall: campaignPaywall)

    let info = viewController.info
    #expect(info.presentedByPlacementWithName == "campaign_trigger")
    #expect(info.experiment?.id == "181395")
    #expect(info.experiment?.variant.id == "633524")
    #expect(info.presentationSourceType == "register")
  }

  @Test
  func claimWithANewPaywallVersionLoadsThatVersion() {
    let viewController = cachedViewController(for: sessionStartPaywall, placement: "session_start")
    #expect(!viewController.didLoadWebView)

    var newVersion = campaignPaywall
    newVersion.cacheKey = "newVersion"
    claim(viewController, placement: "campaign_trigger", paywall: newVersion)

    #expect(viewController.paywall.cacheKey == "newVersion")
    #expect(viewController.didLoadWebView)
    #expect(viewController.info.experiment?.id == "181395")
  }

  @Test
  func reloadForANewVersionIsAnnouncedToTheClaimsDelegate() {
    let viewController = cachedViewController(for: sessionStartPaywall, placement: "session_start")

    var newVersion = embeddedPaywall
    newVersion.cacheKey = "newVersion"
    claim(viewController, placement: "embedded", paywall: newVersion, type: getPaywallType)

    #expect(viewController.delegateAtLoad != nil)
    #expect(viewController.delegateAtLoad === viewController.delegate)
  }

  @Test
  func restoreWithANewVersionStartsOneLoadEvenAfterAFailedLoad() {
    let viewController = cachedViewController(for: sessionStartPaywall, placement: "session_start")
    // The view is loaded before a paywall is ever shown, which does the first load.
    viewController.loadViewIfNeeded()
    viewController.loadWebViewCount = 0
    viewController.isOnScreen = true
    var newVersion = embeddedPaywall
    newVersion.cacheKey = "newVersion"
    claim(viewController, placement: "embedded", paywall: newVersion, type: getPaywallType)
    viewController.isOnScreen = false

    // The web content process died while off screen.
    viewController.webView.loadingHandler.didFailToLoad = true
    viewController.viewWillAppear(false)

    #expect(viewController.loadWebViewCount == 1)
    #expect(viewController.paywall.cacheKey == "newVersion")
  }

  @Test
  func claimWithTheSamePaywallVersionDoesNotReload() {
    let viewController = cachedViewController(for: sessionStartPaywall, placement: "session_start")

    claim(viewController, placement: "campaign_trigger", paywall: campaignPaywall)

    #expect(!viewController.didLoadWebView)
    #expect(viewController.info.experiment?.id == "181395")
  }

  @Test
  func restoredClaimWithANewPaywallVersionLoadsThatVersion() {
    let viewController = cachedViewController(for: sessionStartPaywall, placement: "session_start")
    viewController.isOnScreen = true

    // The paywall is republished while on screen, and the app fetches it.
    var newVersion = embeddedPaywall
    newVersion.cacheKey = "newVersion"
    claim(viewController, placement: "embedded", paywall: newVersion, type: getPaywallType)
    #expect(viewController.paywall.cacheKey == sessionStartPaywall.cacheKey)
    #expect(!viewController.didLoadWebView)

    // The presentation ends and the app shows its handle.
    viewController.isOnScreen = false
    viewController.viewWillAppear(false)

    #expect(viewController.paywall.cacheKey == "newVersion")
    #expect(viewController.didLoadWebView)
    expectEmbeddedAttribution(viewController.info)
  }

  @Test
  func interleavedRequestsReportThePresentingRequest() async throws {
    let paywallManager = try #require(dependencyContainer.paywallManager)
    let paywallA = sessionStartPaywall

    // Both requests fetch the view controller before either presents.
    let viewControllerA = try await paywallManager.getViewController(
      for: paywallA,
      isDebuggerLaunched: false,
      isForPresentation: true,
      delegate: nil
    )
    let viewControllerB = try await paywallManager.getViewController(
      for: campaignPaywall,
      isDebuggerLaunched: false,
      isForPresentation: true,
      delegate: nil
    )
    #expect(viewControllerB === viewControllerA)

    // Request A presents. Everything it reports must be A's.
    claim(viewControllerA, placement: "session_start", paywall: paywallA)

    expectSessionStartAttribution(viewControllerA.info)
  }

  // MARK: - While on screen

  @Test
  func requestWhilePresentedLeavesViewControllerAlone() async throws {
    let presented = cachedViewController(for: sessionStartPaywall, placement: "session_start")
    presented.isOnScreen = true

    // A main-campaign placement whose variant uses the same paywall fires
    // while the session-start paywall is on screen.
    let paywallManager = try #require(dependencyContainer.paywallManager)
    let viewControllerB = try await paywallManager.getViewController(
      for: campaignPaywall,
      isDebuggerLaunched: false,
      isForPresentation: true,
      delegate: nil
    )

    #expect(viewControllerB === presented)
    expectSessionStartAttribution(presented.info)
  }

  @Test
  func presentedViewControllerIsNotReplacedByANewPaywallVersion() async throws {
    let paywallA = sessionStartPaywall
    let presented = cachedViewController(for: paywallA, placement: "session_start")
    presented.isOnScreen = true

    // The paywall was republished, so the same request now resolves to a new
    // version. The cache would normally swap it in and reload the web view.
    var newVersion = campaignPaywall
    newVersion.cacheKey = "newVersion"
    let paywallManager = try #require(dependencyContainer.paywallManager)
    let viewController = try await paywallManager.getViewController(
      for: newVersion,
      isDebuggerLaunched: false,
      isForPresentation: true,
      delegate: nil
    )

    #expect(viewController === presented)
    #expect(presented.paywall.cacheKey == paywallA.cacheKey)
    #expect(!presented.didLoadWebView)
    expectSessionStartAttribution(presented.info)
  }

  @Test
  func presentedViewControllerCannotBeClaimedByAnotherRequest() {
    let presented = cachedViewController(for: sessionStartPaywall, placement: "session_start")
    presented.isOnScreen = true

    // `getPaywall` claims after fetching. If the view controller went on
    // screen for another placement in between, the claim must not take it.
    claim(presented, placement: "campaign_trigger", paywall: campaignPaywall)

    expectSessionStartAttribution(presented.info)
  }

  // MARK: - Handed out via getPaywall

  @Test
  func getPaywallClaimWhilePresentedIsRestoredWhenTheAppShowsIt() {
    let presented = cachedViewController(for: sessionStartPaywall, placement: "session_start")
    presented.isOnScreen = true

    // The app calls `getPaywall` for the paywall that's on screen. It gets the
    // view controller back, but the presentation must not change.
    claim(presented, placement: "embedded", paywall: embeddedPaywall, type: getPaywallType)
    expectSessionStartAttribution(presented.info)
    #expect(presented.delegate == nil)

    // The presentation ends and the app shows the view controller it holds.
    presented.isOnScreen = false
    presented.viewWillAppear(false)

    expectEmbeddedAttribution(presented.info)
    #expect(presented.delegate != nil)
  }

  @Test
  func secondGetPaywallWhileTheAppShowsItDoesNotChangeThePresentation() {
    let viewController = cachedViewController(for: embeddedPaywall, placement: "embedded")
    claim(viewController, placement: "embedded", paywall: embeddedPaywall, type: getPaywallType)
    show(viewController)
    viewController.isOnScreen = true
    let delegate = viewController.delegate

    // The app calls `getPaywall` again for the same paywall while it's showing
    // it, then something like Safari closing makes it appear again.
    claim(viewController, placement: "campaign_trigger", paywall: campaignPaywall, type: getPaywallType)
    viewController.viewWillAppear(false)

    expectEmbeddedAttribution(viewController.info)
    #expect(viewController.delegate === delegate)

    // Once that presentation ends, the newer claim is what the app gets.
    hide(viewController)
    viewController.isOnScreen = false
    viewController.viewWillAppear(false)

    #expect(viewController.info.presentedByPlacementWithName == "campaign_trigger")
    #expect(viewController.info.experiment?.id == "181395")
  }

  @Test
  func handedOutViewControllerReportsItsOwnPlacementWhenTheAppShowsIt() {
    let viewController = cachedViewController(for: embeddedPaywall, placement: "embedded")
    // The app fetched it with `getPaywall` and is holding on to it.
    claim(viewController, placement: "embedded", paywall: embeddedPaywall, type: getPaywallType)

    // `register` presents the same paywall for another placement, then it's dismissed.
    claim(viewController, placement: "session_start", paywall: sessionStartPaywall)
    viewController.isOnScreen = true
    #expect(viewController.info.presentedByPlacementWithName == "session_start")
    viewController.isOnScreen = false

    // The app now shows the view controller it was holding.
    viewController.viewWillAppear(false)

    expectEmbeddedAttribution(viewController.info)
  }

  /// The mirror of the test above: the same armed handle, but the SDK is the
  /// one presenting, so the appearance belongs to the SDK's request.
  @Test
  func sdkPresentationReportsItsOwnPlacementOverAHandedOutClaim() {
    let viewController = cachedViewController(for: embeddedPaywall, placement: "embedded")
    // The app fetched it with `getPaywall` and is holding on to it.
    claim(viewController, placement: "embedded", paywall: embeddedPaywall, type: getPaywallType)

    // `register` presents the same paywall for another placement.
    let presenter = CompletingPresenter()
    viewController.present(
      on: presenter,
      request: request(placement: "session_start"),
      paywall: sessionStartPaywall,
      unsavedOccurrence: nil,
      presentationStyleOverride: nil,
      paywallStatePublisher: .init(),
      completion: { _ in }
    )
    #expect(presenter.presented === viewController)

    viewController.viewWillAppear(false)

    expectSessionStartAttribution(viewController.info)
  }

  @Test
  func handedOutOccurrenceIsSavedWhenTheAppFirstShowsIt() {
    let coreDataManager = OccurrenceCountingCoreDataManager()
    let storage = Storage(factory: dependencyContainer, cache: Cache(), coreDataManager: coreDataManager)
    Self.retained.append(storage)
    let viewController = cachedViewController(
      for: embeddedPaywall,
      placement: "embedded",
      storage: storage
    )
    claim(
      viewController,
      placement: "embedded",
      paywall: embeddedPaywall,
      type: getPaywallType,
      unsavedOccurrence: .stub()
    )

    // `register` claims the paywall before the app has shown its handle.
    claim(viewController, placement: "session_start", paywall: sessionStartPaywall)

    show(viewController)

    #expect(coreDataManager.savedOccurrences == 1)
    expectEmbeddedAttribution(viewController.info)
  }

  @Test
  func restoredClaimDoesNotSaveItsOccurrenceAgain() {
    let coreDataManager = OccurrenceCountingCoreDataManager()
    let storage = Storage(factory: dependencyContainer, cache: Cache(), coreDataManager: coreDataManager)
    Self.retained.append(storage)
    let viewController = cachedViewController(
      for: embeddedPaywall,
      placement: "embedded",
      storage: storage
    )
    claim(
      viewController,
      placement: "embedded",
      paywall: embeddedPaywall,
      type: getPaywallType,
      unsavedOccurrence: .stub()
    )

    // The app shows and hides its handle, which saves the occurrence.
    show(viewController)
    hide(viewController)
    #expect(coreDataManager.savedOccurrences == 1)

    // `register` claims the paywall, then the app shows its handle again.
    claim(viewController, placement: "session_start", paywall: sessionStartPaywall)
    show(viewController)

    #expect(coreDataManager.savedOccurrences == 1)
    expectEmbeddedAttribution(viewController.info)
  }

  @Test
  func restoredClaimGetsAFreshStatePublisherAfterTheOldOneCompleted() async throws {
    let viewController = cachedViewController(for: embeddedPaywall, placement: "embedded")
    let publisher = PassthroughSubject<PaywallState, Never>()
    final class Completion { var done = false }
    let completion = Completion()
    let subscription = publisher.sink(
      receiveCompletion: { _ in completion.done = true },
      receiveValue: { _ in }
    )
    defer { subscription.cancel() }
    claim(
      viewController,
      placement: "embedded",
      paywall: embeddedPaywall,
      type: getPaywallType,
      paywallStatePublisher: publisher
    )

    // The app shows and hides its handle. Dismissal completes the publisher.
    show(viewController)
    hide(viewController)
    for _ in 0..<200 where !completion.done {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(completion.done)

    // `register` claims the paywall, then the app shows its handle again.
    claim(viewController, placement: "session_start", paywall: sessionStartPaywall)
    show(viewController)

    let stored = try #require(Superwall.shared.presentationItems.last)
    #expect(stored.request.presentationInfo.placementName == "embedded")
    #expect(stored.statePublisher !== publisher)
    expectEmbeddedAttribution(viewController.info)
  }

  @Test
  func appearingWithoutAHandedOutClaimKeepsTheCurrentRequest() {
    let viewController = cachedViewController(for: sessionStartPaywall, placement: "session_start")

    viewController.viewWillAppear(false)

    expectSessionStartAttribution(viewController.info)
  }
}
