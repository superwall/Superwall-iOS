//
//  PageViewMessageTests.swift
//
//  Created by Claude on 2026-03-06.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

struct PageViewMessageTests {
  private func decodeMessage(_ json: String) throws -> PaywallMessage {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let data = json.data(using: .utf8)!
    return try decoder.decode(PaywallMessage.self, from: data)
  }

  @Test func decodePageView_allFields() throws {
    let json = """
    {
      "event_name": "page_view",
      "page_node_id": "node_123",
      "page_index": 2,
      "page_name": "Pricing",
      "navigation_node_id": "nav_456",
      "previous_page_node_id": "node_789",
      "previous_page_index": 1,
      "type": "forward",
      "time_on_previous_page_ms": 5000
    }
    """

    let message = try decodeMessage(json)

    if case let .pageView(pageNodeId, pageIndex, pageName, navigationNodeId, previousPageNodeId, previousPageIndex, type, timeOnPreviousPageMs) = message {
      #expect(pageNodeId == "node_123")
      #expect(pageIndex == 2)
      #expect(pageName == "Pricing")
      #expect(navigationNodeId == "nav_456")
      #expect(previousPageNodeId == "node_789")
      #expect(previousPageIndex == 1)
      #expect(type == "forward")
      #expect(timeOnPreviousPageMs == 5000)
    } else {
      Issue.record("Expected .pageView but got \(message)")
    }
  }

  @Test func decodePageView_optionalFieldsMissing() throws {
    let json = """
    {
      "event_name": "page_view",
      "page_node_id": "node_first",
      "page_index": 0,
      "page_name": "Welcome",
      "navigation_node_id": "nav_entry",
      "type": "entry"
    }
    """

    let message = try decodeMessage(json)

    if case let .pageView(pageNodeId, pageIndex, pageName, navigationNodeId, previousPageNodeId, previousPageIndex, type, timeOnPreviousPageMs) = message {
      #expect(pageNodeId == "node_first")
      #expect(pageIndex == 0)
      #expect(pageName == "Welcome")
      #expect(navigationNodeId == "nav_entry")
      #expect(previousPageNodeId == nil)
      #expect(previousPageIndex == nil)
      #expect(type == "entry")
      #expect(timeOnPreviousPageMs == nil)
    } else {
      Issue.record("Expected .pageView but got \(message)")
    }
  }

  @Test func decodePageView_backNavigation() throws {
    let json = """
    {
      "event_name": "page_view",
      "page_node_id": "node_100",
      "page_index": 0,
      "page_name": "Home",
      "navigation_node_id": "nav_back",
      "previous_page_node_id": "node_200",
      "previous_page_index": 1,
      "type": "back",
      "time_on_previous_page_ms": 1200
    }
    """

    let message = try decodeMessage(json)

    if case let .pageView(_, _, _, _, _, _, type, _) = message {
      #expect(type == "back")
    } else {
      Issue.record("Expected .pageView but got \(message)")
    }
  }

  @Test func decodePageView_autoTransition() throws {
    let json = """
    {
      "event_name": "page_view",
      "page_node_id": "node_auto",
      "page_index": 3,
      "page_name": "Auto Page",
      "navigation_node_id": "nav_auto",
      "type": "auto_transition"
    }
    """

    let message = try decodeMessage(json)

    if case let .pageView(_, _, _, _, _, _, type, _) = message {
      #expect(type == "auto_transition")
    } else {
      Issue.record("Expected .pageView but got \(message)")
    }
  }

  // MARK: - PaywallPageView Event

  @Test func paywallPageViewEvent_superwallParameters() async {
    var paywall = Paywall.stub()
    paywall.presentationId = "test-pres-id"
    let info = paywall.getInfo(fromPlacement: nil)

    let event = InternalSuperwallEvent.PaywallPageView(
      paywallInfo: info,
      pageNodeId: "node_abc",
      pageIndex: 1,
      pageName: "Pricing",
      navigationNodeId: "nav_xyz",
      previousPageNodeId: "node_prev",
      previousPageIndex: 0,
      navigationType: "forward",
      timeOnPreviousPageMs: 3000
    )

    let params = await event.getSuperwallParameters()

    // Page view specific params
    #expect(params["page_node_id"] as? String == "node_abc")
    #expect(params["page_index"] as? Int == 1)
    #expect(params["page_name"] as? String == "Pricing")
    #expect(params["navigation_node_id"] as? String == "nav_xyz")
    #expect(params["navigation_type"] as? String == "forward")
    #expect(params["previous_page_node_id"] as? String == "node_prev")
    #expect(params["previous_page_index"] as? Int == 0)
    #expect(params["time_on_previous_page_ms"] as? Int == 3000)

    // Inherited from placementParams (presentation_id)
    #expect(params["presentation_id"] as? String == "test-pres-id")

    // Standard paywall params should be present too
    #expect(params["paywall_identifier"] != nil)
  }

  @Test func paywallPageViewEvent_optionalParamsOmitted() async {
    let info = PaywallInfo.stub()

    let event = InternalSuperwallEvent.PaywallPageView(
      paywallInfo: info,
      pageNodeId: "node_first",
      pageIndex: 0,
      pageName: "Welcome",
      navigationNodeId: "nav_entry",
      previousPageNodeId: nil,
      previousPageIndex: nil,
      navigationType: "entry",
      timeOnPreviousPageMs: nil
    )

    let params = await event.getSuperwallParameters()

    #expect(params["page_node_id"] as? String == "node_first")
    #expect(params["navigation_type"] as? String == "entry")
    #expect(params["previous_page_node_id"] == nil)
    #expect(params["previous_page_index"] == nil)
    #expect(params["time_on_previous_page_ms"] == nil)
  }

  @Test func paywallPageViewEvent_audienceFilterParams() {
    let info = PaywallInfo.stub()

    let event = InternalSuperwallEvent.PaywallPageView(
      paywallInfo: info,
      pageNodeId: "node_abc",
      pageIndex: 0,
      pageName: "Page",
      navigationNodeId: "nav_1",
      previousPageNodeId: nil,
      previousPageIndex: nil,
      navigationType: "entry",
      timeOnPreviousPageMs: nil
    )

    let filterParams = event.audienceFilterParams
    // Should contain standard paywall audience filter params
    #expect(filterParams["paywall_id"] != nil)
    #expect(filterParams["paywall_name"] != nil)
  }

  @Test func paywallPageViewEvent_superwallEventCase() {
    let info = PaywallInfo.stub()

    let event = InternalSuperwallEvent.PaywallPageView(
      paywallInfo: info,
      pageNodeId: "n",
      pageIndex: 0,
      pageName: "P",
      navigationNodeId: "nav",
      previousPageNodeId: nil,
      previousPageIndex: nil,
      navigationType: "entry",
      timeOnPreviousPageMs: nil
    )

    if case .paywallPageView(let eventInfo) = event.superwallEvent {
      #expect(eventInfo === info)
    } else {
      Issue.record("Expected .paywallPageView")
    }
  }

  @Test func paywallPageViewEvent_description() {
    let info = PaywallInfo.stub()

    let event = InternalSuperwallEvent.PaywallPageView(
      paywallInfo: info,
      pageNodeId: "n",
      pageIndex: 0,
      pageName: "P",
      navigationNodeId: "nav",
      previousPageNodeId: nil,
      previousPageIndex: nil,
      navigationType: "entry",
      timeOnPreviousPageMs: nil
    )

    #expect(event.superwallEvent.description == "paywallPageView")
  }

  // MARK: - PresentationId in PageView events

  @Test func paywallPageView_presentationId_matchesPaywallOpen() async {
    var paywall = Paywall.stub()
    paywall.presentationId = "shared-pres-id"
    let info = paywall.getInfo(fromPlacement: nil)

    let openEvent = InternalSuperwallEvent.PaywallOpen(
      paywallInfo: info,
      demandScore: nil,
      demandTier: nil
    )
    let openParams = await openEvent.getSuperwallParameters()

    let pageViewEvent = InternalSuperwallEvent.PaywallPageView(
      paywallInfo: info,
      pageNodeId: "node1",
      pageIndex: 0,
      pageName: "Page",
      navigationNodeId: "nav1",
      previousPageNodeId: nil,
      previousPageIndex: nil,
      navigationType: "entry",
      timeOnPreviousPageMs: nil
    )
    let pageViewParams = await pageViewEvent.getSuperwallParameters()

    let openPresentationId = openParams["presentation_id"] as? String
    let pageViewPresentationId = pageViewParams["presentation_id"] as? String

    #expect(openPresentationId == "shared-pres-id")
    #expect(pageViewPresentationId == "shared-pres-id")
    #expect(openPresentationId == pageViewPresentationId)
  }

  @Test func presentationId_consistentAcrossAllEventTypes() async {
    var paywall = Paywall.stub()
    paywall.presentationId = "lifecycle-id"
    let info = paywall.getInfo(fromPlacement: nil)

    let openParams = await InternalSuperwallEvent.PaywallOpen(
      paywallInfo: info,
      demandScore: nil,
      demandTier: nil
    ).getSuperwallParameters()

    let pageViewParams = await InternalSuperwallEvent.PaywallPageView(
      paywallInfo: info,
      pageNodeId: "n", pageIndex: 0, pageName: "P",
      navigationNodeId: "nav",
      previousPageNodeId: nil, previousPageIndex: nil,
      navigationType: "entry", timeOnPreviousPageMs: nil
    ).getSuperwallParameters()

    let closeParams = await InternalSuperwallEvent.PaywallClose(
      paywallInfo: info,
      surveyPresentationResult: .noShow
    ).getSuperwallParameters()

    let declineParams = await InternalSuperwallEvent.PaywallDecline(
      paywallInfo: info
    ).getSuperwallParameters()

    let webviewLoadParams = await InternalSuperwallEvent.PaywallWebviewLoad(
      state: .complete,
      paywallInfo: info
    ).getSuperwallParameters()

    let allPresentationIds = [
      openParams["presentation_id"] as? String,
      pageViewParams["presentation_id"] as? String,
      closeParams["presentation_id"] as? String,
      declineParams["presentation_id"] as? String,
      webviewLoadParams["presentation_id"] as? String,
    ]

    // All should be the same non-nil value
    for id in allPresentationIds {
      #expect(id == "lifecycle-id", "All events in a presentation must share the same presentationId")
    }
  }
}
