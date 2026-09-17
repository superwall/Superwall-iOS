//
//  PaywallSharedControllerAttributionTests.swift
//  SuperwallKitTests
//

// swiftlint:disable all

import Foundation
import Testing
import Combine
@testable import SuperwallKit

/// Lets a test say whether the view controller is on screen.
private final class ActivePaywallViewController: PaywallViewController {
  var isOnScreen = false
  override var isActive: Bool { isOnScreen }
}

/// Two campaigns share one paywall, so both requests get the one cached view
/// controller. Whatever a request reports for its presentation must all come
/// from that request, and a presentation that's on screen can't be changed by
/// another request.
@MainActor
struct PaywallSharedControllerAttributionTests {
  private let dependencyContainer = DependencyContainer()

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
    type: PresentationRequestType = .presentation
  ) {
    viewController.set(
      request: request(placement: placement, type: type),
      paywall: paywall,
      paywallStatePublisher: .init(),
      unsavedOccurrence: nil
    )
  }

  /// Puts a view controller for `paywall` in the cache, claimed by `placement`.
  private func cachedViewController(
    for paywall: Paywall,
    placement: String
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
      storage: dependencyContainer.storage,
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

  private func expectSessionStartAttribution(_ info: PaywallInfo) {
    #expect(info.presentedByPlacementWithName == "session_start")
    #expect(info.experiment?.id == "180872")
    #expect(info.experiment?.variant.id == "632038")
    #expect(info.presentationSourceType == "implicit")
  }

  @Test
  func claimAppliesTheRequestsPaywall() {
    let paywallA = paywall(experimentId: "180872", variantId: "632038", source: "implicit")
    let viewController = cachedViewController(for: paywallA, placement: "session_start")

    let paywallB = paywall(experimentId: "181395", variantId: "633524", source: "register")
    claim(viewController, placement: "campaign_trigger", paywall: paywallB)

    let info = viewController.info
    #expect(info.presentedByPlacementWithName == "campaign_trigger")
    #expect(info.experiment?.id == "181395")
    #expect(info.experiment?.variant.id == "633524")
    #expect(info.presentationSourceType == "register")
  }

  @Test
  func requestWhilePresentedLeavesViewControllerAlone() async throws {
    let paywallA = paywall(experimentId: "180872", variantId: "632038", source: "implicit")
    let presented = cachedViewController(for: paywallA, placement: "session_start")
    presented.isOnScreen = true

    // A main-campaign placement whose variant uses the same paywall fires
    // while the session-start paywall is on screen.
    let paywallB = paywall(experimentId: "181395", variantId: "633524", source: "register")
    let paywallManager = try #require(dependencyContainer.paywallManager)
    let viewControllerB = try await paywallManager.getViewController(
      for: paywallB,
      isDebuggerLaunched: false,
      isForPresentation: true,
      delegate: nil
    )

    #expect(viewControllerB === presented)
    expectSessionStartAttribution(presented.info)
  }

  @Test
  func presentedViewControllerCannotBeClaimedByAnotherRequest() {
    let paywallA = paywall(experimentId: "180872", variantId: "632038", source: "implicit")
    let presented = cachedViewController(for: paywallA, placement: "session_start")
    presented.isOnScreen = true

    // `getPaywall` claims after fetching. If the view controller went on
    // screen for another placement in between, the claim must not take it.
    let paywallB = paywall(experimentId: "181395", variantId: "633524", source: "register")
    claim(presented, placement: "campaign_trigger", paywall: paywallB)

    expectSessionStartAttribution(presented.info)
  }

  @Test
  func handedOutViewControllerReportsItsOwnPlacementWhenTheAppShowsIt() {
    let paywallEmbedded = paywall(experimentId: "166736", variantId: "634019", source: "getPaywall")
    let viewController = cachedViewController(for: paywallEmbedded, placement: "embedded")
    // The app fetched it with `getPaywall` and is holding on to it.
    claim(viewController, placement: "embedded", paywall: paywallEmbedded, type: getPaywallType)

    // `register` presents the same paywall for another placement, then it's dismissed.
    let paywallA = paywall(experimentId: "180872", variantId: "632038", source: "implicit")
    claim(viewController, placement: "session_start", paywall: paywallA)
    viewController.isOnScreen = true
    #expect(viewController.info.presentedByPlacementWithName == "session_start")
    viewController.isOnScreen = false

    // The app now shows the view controller it was holding.
    viewController.viewWillAppear(false)

    let info = viewController.info
    #expect(info.presentedByPlacementWithName == "embedded")
    #expect(info.experiment?.id == "166736")
    #expect(info.experiment?.variant.id == "634019")
    #expect(info.presentationSourceType == "getPaywall")
  }

  @Test
  func appearingWithoutAHandedOutClaimKeepsTheCurrentRequest() {
    let paywallA = paywall(experimentId: "180872", variantId: "632038", source: "implicit")
    let viewController = cachedViewController(for: paywallA, placement: "session_start")

    viewController.viewWillAppear(false)

    expectSessionStartAttribution(viewController.info)
  }

  @Test
  func interleavedRequestsReportThePresentingRequest() async throws {
    let paywallManager = try #require(dependencyContainer.paywallManager)
    let paywallA = paywall(experimentId: "180872", variantId: "632038", source: "implicit")
    let paywallB = paywall(experimentId: "181395", variantId: "633524", source: "register")

    // Both requests fetch the view controller before either presents.
    let viewControllerA = try await paywallManager.getViewController(
      for: paywallA,
      isDebuggerLaunched: false,
      isForPresentation: true,
      delegate: nil
    )
    let viewControllerB = try await paywallManager.getViewController(
      for: paywallB,
      isDebuggerLaunched: false,
      isForPresentation: true,
      delegate: nil
    )
    #expect(viewControllerB === viewControllerA)

    // Request A presents. Everything it reports must be A's.
    claim(viewControllerA, placement: "session_start", paywall: paywallA)

    expectSessionStartAttribution(viewControllerA.info)
  }
}
