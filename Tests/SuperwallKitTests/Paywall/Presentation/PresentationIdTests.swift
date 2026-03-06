//
//  PresentationIdTests.swift
//
//  Created by Claude on 2026-03-06.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

struct PresentationIdTests {
  // MARK: - Paywall.presentationId

  @Test func paywall_presentationId_isNilByDefault() {
    let paywall = Paywall.stub()
    #expect(paywall.presentationId == nil)
  }

  @Test func paywall_presentationId_canBeSet() {
    var paywall = Paywall.stub()
    paywall.presentationId = "test-uuid"
    #expect(paywall.presentationId == "test-uuid")
  }

  @Test func paywall_presentationId_survivesUpdate() {
    var paywall = Paywall.stub()
    paywall.presentationId = "original-id"

    var newPaywall = Paywall.stub()
    newPaywall.presentationId = "new-id"

    paywall.update(from: newPaywall)
    #expect(paywall.presentationId == "new-id")
  }

  @Test func paywall_presentationId_passedThroughGetInfo() {
    var paywall = Paywall.stub()
    paywall.presentationId = "test-presentation-id"

    let info = paywall.getInfo(fromPlacement: nil)
    #expect(info.presentationId == "test-presentation-id")
  }

  @Test func paywall_presentationId_nilWhenNotSet() {
    let paywall = Paywall.stub()
    let info = paywall.getInfo(fromPlacement: nil)
    #expect(info.presentationId == nil)
  }

  // MARK: - PaywallInfo.presentationId in placementParams

  @Test func paywallInfo_placementParams_includesPresentationId() async {
    var paywall = Paywall.stub()
    paywall.presentationId = "my-presentation-id"
    let info = paywall.getInfo(fromPlacement: nil)

    let params = await info.placementParams()
    #expect(params["presentation_id"] as? String == "my-presentation-id")
  }

  @Test func paywallInfo_placementParams_presentationIdIsNilWhenNotSet() async {
    let paywall = Paywall.stub()
    let info = paywall.getInfo(fromPlacement: nil)

    let params = await info.placementParams()
    // When presentationId is nil, it should still be present as a key (via `as Any`)
    // but the value should be nil/NSNull
    let value = params["presentation_id"]
    #expect(value is NSNull || value == nil || "\(value!)" == "Optional(nil)")
  }

  // MARK: - PresentationId consistency across info calls

  @Test func paywallInfo_presentationId_consistentAcrossMultipleInfoCalls() {
    var paywall = Paywall.stub()
    paywall.presentationId = "stable-id"

    let info1 = paywall.getInfo(fromPlacement: nil)
    let info2 = paywall.getInfo(fromPlacement: nil)
    let info3 = paywall.getInfo(fromPlacement: nil)

    #expect(info1.presentationId == "stable-id")
    #expect(info2.presentationId == "stable-id")
    #expect(info3.presentationId == "stable-id")
  }

  @Test func paywallInfo_presentationId_doesNotChangeWhenPaywallMutated() {
    var paywall = Paywall.stub()
    paywall.presentationId = "stable-id"

    let info1 = paywall.getInfo(fromPlacement: nil)

    // Mutate paywall properties that change during lifecycle
    paywall.paywalljsVersion = "1.0"
    paywall.isFreeTrialAvailable = true
    paywall.closeReason = .manualClose

    let info2 = paywall.getInfo(fromPlacement: nil)

    #expect(info1.presentationId == info2.presentationId)
  }

  // MARK: - PresentationId uniqueness per presentation

  @Test func presentationId_uniquePerPresentation() {
    // Simulates two separate presentations getting different IDs
    var paywall1 = Paywall.stub()
    paywall1.presentationId = UUID().uuidString

    var paywall2 = Paywall.stub()
    paywall2.presentationId = UUID().uuidString

    #expect(paywall1.presentationId != paywall2.presentationId)
  }

  // MARK: - Full presentation lifecycle simulation
  //
  // In the real app, PaywallViewController.info is a computed property:
  //   var info: PaywallInfo { paywall.getInfo(fromPlacement: ...) }
  // It's called fresh at every event point. These tests simulate that.

  @Test func lifecycle_presentationId_stableFromOpenThroughClose() async {
    // Simulate: getRawPaywall sets presentationId
    var paywall = Paywall.stub()
    paywall.presentationId = UUID().uuidString
    let presentationId = paywall.presentationId!

    // Simulate: onReady fires, paywalljsVersion is set
    paywall.paywalljsVersion = "4.2.0"
    let infoAtReady = paywall.getInfo(fromPlacement: nil)
    #expect(infoAtReady.presentationId == presentationId)

    // Simulate: webview load complete
    paywall.webviewLoadingInfo.endAt = Date()
    let infoAtWebviewLoad = paywall.getInfo(fromPlacement: nil)
    #expect(infoAtWebviewLoad.presentationId == presentationId)

    // Simulate: paywall_open event
    let openParams = await InternalSuperwallEvent.PaywallOpen(
      paywallInfo: paywall.getInfo(fromPlacement: nil),
      demandScore: nil,
      demandTier: nil
    ).getSuperwallParameters()
    #expect(openParams["presentation_id"] as? String == presentationId)

    // Simulate: page_view events as user navigates
    let pageView1Params = await InternalSuperwallEvent.PaywallPageView(
      paywallInfo: paywall.getInfo(fromPlacement: nil),
      pageNodeId: "page1", flowPosition: 0, pageName: "Welcome",
      navigationNodeId: "nav1",
      previousPageNodeId: nil, previousFlowPosition: nil,
      navigationType: "entry", timeOnPreviousPageMs: nil
    ).getSuperwallParameters()
    #expect(pageView1Params["presentation_id"] as? String == presentationId)

    let pageView2Params = await InternalSuperwallEvent.PaywallPageView(
      paywallInfo: paywall.getInfo(fromPlacement: nil),
      pageNodeId: "page2", flowPosition: 1, pageName: "Pricing",
      navigationNodeId: "nav2",
      previousPageNodeId: "page1", previousFlowPosition: 0,
      navigationType: "forward", timeOnPreviousPageMs: 4500
    ).getSuperwallParameters()
    #expect(pageView2Params["presentation_id"] as? String == presentationId)

    // Simulate: user goes back
    let pageView3Params = await InternalSuperwallEvent.PaywallPageView(
      paywallInfo: paywall.getInfo(fromPlacement: nil),
      pageNodeId: "page1", flowPosition: 0, pageName: "Welcome",
      navigationNodeId: "nav3",
      previousPageNodeId: "page2", previousFlowPosition: 1,
      navigationType: "back", timeOnPreviousPageMs: 2000
    ).getSuperwallParameters()
    #expect(pageView3Params["presentation_id"] as? String == presentationId)

    // Simulate: paywall_decline
    let declineParams = await InternalSuperwallEvent.PaywallDecline(
      paywallInfo: paywall.getInfo(fromPlacement: nil)
    ).getSuperwallParameters()
    #expect(declineParams["presentation_id"] as? String == presentationId)

    // Simulate: paywall_close
    paywall.closeReason = .manualClose
    let closeParams = await InternalSuperwallEvent.PaywallClose(
      paywallInfo: paywall.getInfo(fromPlacement: nil),
      surveyPresentationResult: .noShow
    ).getSuperwallParameters()
    #expect(closeParams["presentation_id"] as? String == presentationId)
  }

  @Test func lifecycle_cachedVC_getsNewPresentationIdOnRePresentation() async {
    // First presentation
    var paywall = Paywall.stub()
    paywall.presentationId = UUID().uuidString
    let firstPresentationId = paywall.presentationId!

    let openParams1 = await InternalSuperwallEvent.PaywallOpen(
      paywallInfo: paywall.getInfo(fromPlacement: nil),
      demandScore: nil,
      demandTier: nil
    ).getSuperwallParameters()
    #expect(openParams1["presentation_id"] as? String == firstPresentationId)

    // User closes paywall
    paywall.closeReason = .manualClose
    let closeParams1 = await InternalSuperwallEvent.PaywallClose(
      paywallInfo: paywall.getInfo(fromPlacement: nil),
      surveyPresentationResult: .noShow
    ).getSuperwallParameters()
    #expect(closeParams1["presentation_id"] as? String == firstPresentationId)

    // Second presentation: simulate update(from:) with new presentationId
    // This is what happens when the cached VC is reused
    var newPaywall = Paywall.stub()
    newPaywall.presentationId = UUID().uuidString
    let secondPresentationId = newPaywall.presentationId!

    paywall.update(from: newPaywall)

    // The paywall now has the NEW presentationId
    #expect(paywall.presentationId == secondPresentationId)
    #expect(secondPresentationId != firstPresentationId)

    // All events in the second presentation use the new ID
    let openParams2 = await InternalSuperwallEvent.PaywallOpen(
      paywallInfo: paywall.getInfo(fromPlacement: nil),
      demandScore: nil,
      demandTier: nil
    ).getSuperwallParameters()
    #expect(openParams2["presentation_id"] as? String == secondPresentationId)

    let pageViewParams2 = await InternalSuperwallEvent.PaywallPageView(
      paywallInfo: paywall.getInfo(fromPlacement: nil),
      pageNodeId: "p1", flowPosition: 0, pageName: "Page",
      navigationNodeId: "n1",
      previousPageNodeId: nil, previousFlowPosition: nil,
      navigationType: "entry", timeOnPreviousPageMs: nil
    ).getSuperwallParameters()
    #expect(pageViewParams2["presentation_id"] as? String == secondPresentationId)
  }

  @Test func lifecycle_presentationId_neverLeaksBetweenPresentations() async {
    // Simulate 3 consecutive presentations of the same cached paywall
    var paywall = Paywall.stub()

    var allPresentationIds: [String] = []

    for i in 0..<3 {
      // Each presentation gets a new ID (simulating getRawPaywall or update(from:))
      var incoming = Paywall.stub()
      incoming.presentationId = UUID().uuidString
      paywall.update(from: incoming)

      let currentId = paywall.presentationId!
      allPresentationIds.append(currentId)

      // Simulate multiple events within this presentation
      let openInfo = paywall.getInfo(fromPlacement: nil)
      let openParams = await InternalSuperwallEvent.PaywallOpen(
        paywallInfo: openInfo, demandScore: nil, demandTier: nil
      ).getSuperwallParameters()

      let pageViewInfo = paywall.getInfo(fromPlacement: nil)
      let pageViewParams = await InternalSuperwallEvent.PaywallPageView(
        paywallInfo: pageViewInfo,
        pageNodeId: "p\(i)", flowPosition: 0, pageName: "Page \(i)",
        navigationNodeId: "n\(i)",
        previousPageNodeId: nil, previousFlowPosition: nil,
        navigationType: "entry", timeOnPreviousPageMs: nil
      ).getSuperwallParameters()

      paywall.closeReason = .manualClose
      let closeInfo = paywall.getInfo(fromPlacement: nil)
      let closeParams = await InternalSuperwallEvent.PaywallClose(
        paywallInfo: closeInfo, surveyPresentationResult: .noShow
      ).getSuperwallParameters()

      // All events within this presentation share the same ID
      #expect(openParams["presentation_id"] as? String == currentId)
      #expect(pageViewParams["presentation_id"] as? String == currentId)
      #expect(closeParams["presentation_id"] as? String == currentId)
    }

    // All 3 presentations have different IDs
    let uniqueIds = Set(allPresentationIds)
    #expect(uniqueIds.count == 3, "Each presentation must have a unique presentationId")
  }

  // MARK: - PaywallInfo stubs

  @Test func paywallInfo_stub_hasPresentationIdNil() {
    let stub = PaywallInfo.stub()
    #expect(stub.presentationId == nil)
  }

  @Test func paywallInfo_empty_hasPresentationIdNil() {
    let empty = PaywallInfo.empty()
    #expect(empty.presentationId == nil)
  }
}
