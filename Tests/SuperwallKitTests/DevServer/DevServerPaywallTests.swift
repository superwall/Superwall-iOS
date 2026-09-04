//
//  DevServerPaywallTests.swift
//  SuperwallKitTests
//

import XCTest
@testable import SuperwallKit

final class DevServerPaywallTests: XCTestCase {
  private func surface(
    id: String = "pro",
    paywallId: String? = nil,
    identifier: String? = nil,
    products: [String: String]? = nil
  ) -> DevServerSurface {
    let json = """
    {
      "kind": "paywall",
      "id": "\(id)",
      "url": "/preview/paywall/\(id)",
      \(paywallId.map { "\"paywallId\": \"\($0)\"," } ?? "")
      \(identifier.map { "\"identifier\": \"\($0)\"," } ?? "")
      "products": \(products.map { dict in
        "{" + dict.map { "\"\($0.key)\": \"\($0.value)\"" }.sorted().joined(separator: ",") + "}"
      } ?? "null")
    }
    """
    // swiftlint:disable:next force_try
    return try! JSONDecoder().decode(DevServerSurface.self, from: Data(json.utf8))
  }

  private let url = URL(string: "http://localhost:6100/preview/paywall/pro")!

  func test_pointsEveryUrlAtTheDevServerAndDisablesTheArchive() {
    let paywall = Paywall.devServer(surface: surface(), url: url)

    XCTAssertEqual(paywall.url, url)
    XCTAssertEqual(paywall.urlConfig.endpoints.map { $0.url }, [url])
    XCTAssertEqual(paywall.urlConfig.maxAttempts, 1)
    // a local build is never the archived, published bytes
    XCTAssertNil(paywall.manifest)
    XCTAssertFalse(paywall.isUsingManifest)
  }

  func test_carriesTheProductsTheSurfaceDeclares() {
    let paywall = Paywall.devServer(
      surface: surface(products: ["plus": "chatgpt_plus_1999_month", "go": "chatgpt_go_999_month"]),
      url: url
    )

    // sorted by reference name, so the order is stable across runs
    XCTAssertEqual(paywall.products.map { $0.name }, ["go", "plus"])
    XCTAssertEqual(paywall.productIds, ["chatgpt_go_999_month", "chatgpt_plus_1999_month"])
    XCTAssertEqual(paywall.appStoreProductIds, ["chatgpt_go_999_month", "chatgpt_plus_1999_month"])
  }

  func test_worksForASurfaceThatHasNeverBeenPushed() {
    let paywall = Paywall.devServer(surface: surface(id: "draft"), url: url)

    XCTAssertEqual(paywall.name, "draft")
    XCTAssertTrue(paywall.databaseId.contains("draft"))
    XCTAssertTrue(paywall.identifier.contains("draft"))
    XCTAssertTrue(paywall.products.isEmpty)
  }

  func test_keepsTheDashboardIdentityOfAPushedSurface() {
    let paywall = Paywall.devServer(
      surface: surface(paywallId: "253583", identifier: "chatgpt-plus"),
      url: url
    )

    XCTAssertEqual(paywall.databaseId, "253583")
    XCTAssertEqual(paywall.identifier, "chatgpt-plus")
  }

  func test_isMarkedLocalSoEventsCanSaySo() {
    let paywall = Paywall.devServer(surface: surface(), url: url)

    XCTAssertTrue(paywall.isLocal)
    let params = paywall.getInfo(fromPlacement: nil).audienceFilterParams()
    XCTAssertEqual(params["is_local"] as? Bool, true)
  }

  func test_inheritsTheDashboardStyleWhenTheManifestSaysNothing() {
    // The shipped manifest carries no presentation, so a bound paywall has to
    // keep the style the dashboard configured rather than snap to fullscreen.
    var published = Paywall.stub()
    XCTAssertEqual(published.presentation.style, .modal)

    let paywall = Paywall.devServer(surface: surface(), url: url, inheriting: published)

    XCTAssertEqual(paywall.presentation.style, .modal)

    // Visual settings the manifest can't carry come from there too.
    published = Paywall.stub()
    let visuals = Paywall.devServer(surface: surface(), url: url, inheriting: published)
    XCTAssertEqual(visuals.backgroundColorHex, published.backgroundColorHex)
    XCTAssertEqual(visuals.isScrollEnabled, published.isScrollEnabled)
  }

  func test_presentsFullscreenWhenNothingDeclaresAStyle() {
    let paywall = Paywall.devServer(surface: surface(), url: url)
    XCTAssertEqual(paywall.presentation.style, .fullscreen)
  }

  // MARK: - Partly specified geometry

  // MARK: - What the dashboard keeps owning

  /// The manifest can't express any of these, so a bound surface has to take
  /// them from the paywall it stands in for or they vanish silently.
  func test_inheritsDashboardOwnedBehaviourFromThePublishedPaywall() {
    var published = Paywall.stub()
    published.featureGating = .gated
    published.surveys = [Survey.stub()]

    let paywall = Paywall.devServer(
      surface: surface(),
      url: url,
      inheriting: published
    )

    XCTAssertEqual(paywall.featureGating, .gated)
    XCTAssertEqual(paywall.surveys.count, 1)
  }

  func test_doesNotInheritNotificationsTheLocalPaywallDeclaresItself() {
    // config.ts can declare notifications, and they arrive as
    // `schedule_notification` messages. Inheriting the dashboard's would let
    // a stale copy win NotificationScheduler's paywallId+type dedupe.
    var published = Paywall.stub()
    published.localNotifications = [LocalNotification.stub()]

    let paywall = Paywall.devServer(surface: surface(), url: url, inheriting: published)

    XCTAssertTrue(paywall.localNotifications.isEmpty)
  }

  func test_inheritsComputedPropertiesAndIntroOfferEligibility() throws {
    let json = """
    {
      "computedPropertyRequests": [
        { "type": "HOURS_SINCE", "eventName": "trigger1" }
      ],
      "introductoryOfferEligibility": "INELIGIBLE"
    }
    """
    // Decoded rather than hand-built so the test pins the real dashboard shape.
    struct Fields: Decodable {
      let computedPropertyRequests: [ComputedPropertyRequest]
      let introductoryOfferEligibility: IntroOfferEligibility
    }
    let fields = try JSONDecoder().decode(Fields.self, from: Data(json.utf8))

    var published = Paywall.stub()
    published = Paywall(
      databaseId: published.databaseId,
      identifier: published.identifier,
      name: published.name,
      cacheKey: published.cacheKey,
      buildId: published.buildId,
      url: published.url,
      urlConfig: published.urlConfig,
      htmlSubstitutions: published.htmlSubstitutions,
      presentation: published.presentation,
      backgroundColorHex: published.backgroundColorHex,
      backgroundColor: published.backgroundColor,
      darkBackgroundColorHex: nil,
      darkBackgroundColor: nil,
      productItems: [],
      productIds: [],
      appStoreProductIds: [],
      responseLoadingInfo: .init(),
      webviewLoadingInfo: .init(),
      productsLoadingInfo: .init(),
      shimmerLoadingInfo: .init(),
      paywalljsVersion: "",
      computedPropertyRequests: fields.computedPropertyRequests,
      isScrollEnabled: true,
      introOfferEligibility: fields.introductoryOfferEligibility
    )

    let paywall = Paywall.devServer(surface: surface(), url: url, inheriting: published)

    XCTAssertEqual(paywall.computedPropertyRequests.count, 1)
    XCTAssertEqual(paywall.introOfferEligibility, fields.introductoryOfferEligibility)
  }

  func test_anUnboundSurfaceKeepsTheSafeDefaults() {
    // The debugger previews surfaces with no dashboard counterpart, so there
    // is nothing to inherit and gating must stay off rather than guess.
    let paywall = Paywall.devServer(surface: surface(), url: url)

    XCTAssertEqual(paywall.featureGating, .nonGated)
    XCTAssertTrue(paywall.surveys.isEmpty)
    XCTAssertTrue(paywall.localNotifications.isEmpty)
    XCTAssertTrue(paywall.computedPropertyRequests.isEmpty)
    XCTAssertEqual(paywall.introOfferEligibility, .automatic)
  }

  func test_theLocalSurfaceStillOwnsWhatItRenders() {
    var published = Paywall.stub()
    published.featureGating = .gated

    let paywall = Paywall.devServer(
      surface: surface(products: ["plus": "local_product"]),
      url: url,
      inheriting: published
    )

    // The surface owns what it serves: its URL and its own products.
    XCTAssertEqual(paywall.url, url)
    XCTAssertEqual(paywall.productIds, ["local_product"])
    XCTAssertTrue(paywall.isLocal)
    XCTAssertNil(paywall.manifest)
    // Inherited behaviour rides along without dragging the published bytes in.
    XCTAssertEqual(paywall.featureGating, .gated)
  }

  func test_settingsTheSurfaceOmitsStillComeFromTheDashboard() {
    var published = Paywall.stub()
    published.featureGating = .gated

    let paywall = Paywall.devServer(surface: surface(), url: url, inheriting: published)

    XCTAssertEqual(paywall.featureGating, .gated)
  }

}
