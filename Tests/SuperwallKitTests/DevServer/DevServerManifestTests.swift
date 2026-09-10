//
//  DevServerManifestTests.swift
//  SuperwallKitTests
//

import XCTest
@testable import SuperwallKit

final class DevServerManifestTests: XCTestCase {
  private func manifest(_ json: String) throws -> DevServerManifest {
    return try JSONDecoder().decode(DevServerManifest.self, from: Data(json.utf8))
  }

  func test_decodesManifestJson() throws {
    let decoded = try manifest("""
    {
      "surfaces": [
        { "kind": "paywall", "id": "pro", "url": "/preview/paywall/pro", "paywallId": "12345" },
        { "kind": "funnel", "id": "onboarding", "url": "/preview/funnel/onboarding" }
      ]
    }
    """)
    XCTAssertEqual(decoded.surfaces.count, 2)
    XCTAssertEqual(decoded.surfaces[0].paywallId, "12345")
    XCTAssertNil(decoded.surfaces[1].paywallId)
  }

  func test_boundPaywallWinsOverSingleFallback() throws {
    let decoded = try manifest("""
    {
      "surfaces": [
        { "kind": "paywall", "id": "pro", "url": "/preview/paywall/pro", "paywallId": "12345" },
        { "kind": "paywall", "id": "max", "url": "/preview/paywall/max", "paywallId": "678" }
      ]
    }
    """)
    XCTAssertEqual(decoded.surface(forPaywallDatabaseId: "678")?.id, "max")
  }

  func test_singlePaywallServesEveryDatabaseId() throws {
    let decoded = try manifest("""
    {
      "surfaces": [
        { "kind": "paywall", "id": "pro", "url": "/preview/paywall/pro" },
        { "kind": "funnel", "id": "onboarding", "url": "/preview/funnel/onboarding" }
      ]
    }
    """)
    XCTAssertEqual(decoded.surface(forPaywallDatabaseId: "anything")?.id, "pro")
  }

  func test_severalUnboundPaywallsMatchNothing() throws {
    let decoded = try manifest("""
    {
      "surfaces": [
        { "kind": "paywall", "id": "pro", "url": "/preview/paywall/pro" },
        { "kind": "paywall", "id": "max", "url": "/preview/paywall/max" }
      ]
    }
    """)
    XCTAssertNil(decoded.surface(forPaywallDatabaseId: "anything"))
  }

  func test_candidatesDefaultToLocalhostAcrossTheDevPortRange() {
    let bases = DevServerCandidates.bases(devServerURL: nil)
    XCTAssertEqual(
      bases.map { $0.absoluteString },
      (6100...6104).map { "http://localhost:\($0)" }
    )
  }

  func test_anExplicitDevServerUrlIsTheOnlyCandidate() throws {
    let url = try XCTUnwrap(URL(string: "http://192.168.1.10:7000"))
    XCTAssertEqual(DevServerCandidates.bases(devServerURL: url), [url])
  }

  func test_decodesTheIdentifierWhenTheManifestCarriesIt() throws {
    let decoded = try manifest("""
    { "surfaces": [{ "kind": "paywall", "id": "pro", "url": "/preview/paywall/pro", "paywallId": "1", "identifier": "pro-slug" }] }
    """)
    XCTAssertEqual(decoded.surfaces.first?.identifier, "pro-slug")
  }

  func test_devLinkOutcomeParsesBaseAndOptionalSurface() throws {
    let base = try XCTUnwrap(URL(string: "exampleapp://?superwall_dev=http://192.168.1.10:6100"))
    let outcome = try XCTUnwrap(DevServerPreview.outcomeForDeepLink(url: base))
    XCTAssertEqual(outcome.base.absoluteString, "http://192.168.1.10:6100")
    XCTAssertNil(outcome.surfaceId)

    let direct = try XCTUnwrap(URL(
      string: "exampleapp://?superwall_dev=http://localhost:6100&superwall_dev_surface=chatgpt-plus"
    ))
    XCTAssertEqual(
      DevServerPreview.outcomeForDeepLink(url: direct)?.surfaceId,
      "chatgpt-plus"
    )
  }

  func test_devLinkOutcomeRejectsNonHttpBasesAndOtherLinks() throws {
    let js = try XCTUnwrap(URL(string: "exampleapp://?superwall_dev=javascript:alert(1)"))
    XCTAssertNil(DevServerPreview.outcomeForDeepLink(url: js))
    let debug = try XCTUnwrap(URL(string: "exampleapp://?superwall_debug=true&token=abc"))
    XCTAssertNil(DevServerPreview.outcomeForDeepLink(url: debug))
  }

  func test_mountUrlResolvesAgainstTheDevServerOrigin() throws {
    let decoded = try manifest("""
    { "surfaces": [{ "kind": "paywall", "id": "pro", "url": "/preview/paywall/pro" }] }
    """)
    let surface = try XCTUnwrap(decoded.surfaces.first)
    let base = try XCTUnwrap(URL(string: "http://192.168.1.10:6100"))
    XCTAssertEqual(
      decoded.mountURL(for: surface, base: base)?.absoluteString,
      "http://192.168.1.10:6100/preview/paywall/pro"
    )
  }

  func test_mountUrlRejectsSurfacesPointingOffTheDevServerOrigin() throws {
    let decoded = try manifest("""
    {
      "surfaces": [
        { "kind": "paywall", "id": "absolute", "url": "https://evil.example.com/x" },
        { "kind": "paywall", "id": "protocol-relative", "url": "//evil.example.com/x" },
        { "kind": "paywall", "id": "other-port", "url": "http://192.168.1.10:9999/x" }
      ]
    }
    """)
    let base = try XCTUnwrap(URL(string: "http://192.168.1.10:6100"))
    for surface in decoded.surfaces {
      XCTAssertNil(decoded.mountURL(for: surface, base: base), surface.id)
    }
  }

  // MARK: - Tolerating what the SDK can't read

  func test_oneUnreadableSurfaceDoesNotDropTheRest() throws {
    // `id` is required, so the middle entry can't decode at all.
    let decoded = try manifest("""
    {
      "surfaces": [
        { "kind": "paywall", "id": "pro", "url": "/preview/paywall/pro" },
        { "kind": "paywall", "url": "/preview/paywall/nameless" },
        { "kind": "paywall", "id": "max", "url": "/preview/paywall/max" }
      ]
    }
    """)
    XCTAssertEqual(decoded.surfaces.map { $0.id }, ["pro", "max"])
  }


  func test_aBodyWithoutSurfacesIsNotAManifest() {
    // `surfaces` is what tells this JSON apart from anything else that might
    // answer on a candidate port, so these must not decode — otherwise the
    // port walk stops on the wrong process.
    for body in ["{}", #"{"detail": "Not Found"}"#, #"{"error": {"code": 404}}"#] {
      XCTAssertThrowsError(try manifest(body), body)
    }
  }

  func test_anEmptySurfaceListIsStillAManifest() throws {
    XCTAssertTrue(try manifest(#"{"surfaces": []}"#).surfaces.isEmpty)
  }

  func test_matchesASurfaceBoundToSeveralPaywalls() {
    // superwall.lock can bind one surface to several paywalls: the CLI sends
    // the first as `paywallId` and the whole set as `paywallIds`.
    // swiftlint:disable:next force_try
    let decoded = try! manifest("""
    {
      "surfaces": [
        { "kind": "paywall", "id": "pro", "url": "/preview/paywall/pro" },
        {
          "kind": "paywall",
          "id": "shared",
          "url": "/preview/paywall/shared",
          "paywallId": "111",
          "paywallIds": ["111", "222", "333"]
        }
      ]
    }
    """)
    XCTAssertEqual(decoded.surface(forPaywallDatabaseId: "111")?.id, "shared")
    XCTAssertEqual(decoded.surface(forPaywallDatabaseId: "222")?.id, "shared")
    XCTAssertEqual(decoded.surface(forPaywallDatabaseId: "333")?.id, "shared")
    XCTAssertNil(decoded.surface(forPaywallDatabaseId: "444"))
  }

  /// The manifest a running `superwall dev` actually serves, copied verbatim
  /// from `/device/manifest.json`, so a change on either side of the wire
  /// fails here rather than on someone's device.
  func test_readsTheManifestTheCliServes() throws {
    let decoded = try manifest("""
    {
      "surfaces": [
        {
          "kind": "paywall",
          "id": "drawer",
          "url": "/preview/paywall/drawer",
          "paywallId": "208552",
          "settings": {
            "presentation_style": { "type": "DRAWER", "height": 60, "corner_radius": 15 },
            "feature_gating": "gated",
            "on_device_cache": false,
            "scroll_enabled": true,
            "game_controller_enabled": true
          }
        },
        {
          "kind": "paywall",
          "id": "demo",
          "url": "/preview/paywall/demo",
          "products": { "primary": "demo_monthly" },
          "settings": {
            "presentation_style": { "type": "FULLSCREEN" },
            "feature_gating": "non_gated",
            "on_device_cache": true,
            "scroll_enabled": true,
            "game_controller_enabled": false,
            "background_color_hex": "#ffffff",
            "dark_background_color_hex": "#0d0f12"
          }
        },
        {
          "kind": "paywall",
          "id": "hosted",
          "url": "/preview/paywall/hosted",
          "settings": {
            "presentation_style": { "type": "FULLSCREEN" },
            "feature_gating": "non_gated",
            "on_device_cache": true,
            "scroll_enabled": true,
            "game_controller_enabled": false,
            "web_checkout_destination": "EXTERNAL"
          }
        }
      ]
    }
    """)

    XCTAssertEqual(decoded.surfaces.count, 3)
    let bound = try XCTUnwrap(decoded.surface(forPaywallDatabaseId: "208552"))
    let url = try XCTUnwrap(URL(string: "http://localhost:6100/preview/paywall/drawer"))

    // A published paywall that disagrees with config.ts on every setting the
    // manifest carries, so nothing here can pass by accident.
    let stub = Paywall.stub()
    let published = Paywall(
      databaseId: "208552",
      identifier: "pro_published",
      name: "Published Pro",
      cacheKey: stub.cacheKey,
      buildId: stub.buildId,
      url: stub.url,
      urlConfig: stub.urlConfig,
      htmlSubstitutions: "",
      presentation: PaywallPresentationInfo(style: .fullscreen, delay: 300),
      backgroundColorHex: "#123456",
      backgroundColor: .blue,
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
      featureGating: .nonGated,
      onDeviceCache: .enabled,
      isScrollEnabled: false,
      introOfferEligibility: .automatic
    )

    let paywall = Paywall.devServer(surface: bound, url: url, inheriting: published)

    XCTAssertEqual(paywall.presentation.style, .drawer(height: 60, cornerRadius: 15))
    XCTAssertEqual(paywall.presentation.delay, 300)
    XCTAssertEqual(paywall.featureGating, .gated)
    XCTAssertTrue(paywall.isScrollEnabled)
    XCTAssertEqual(paywall.onDeviceCache, .disabled)

    // Web-only and app-level settings have no paywall field to land on, so the
    // surfaces carrying them still read cleanly.
    let hosted = try XCTUnwrap(decoded.surfaces.first { $0.id == "hosted" })
    XCTAssertEqual(hosted.settings?.presentationStyle, .fullscreen)

    let demo = try XCTUnwrap(decoded.surfaces.first { $0.id == "demo" })
    XCTAssertEqual(demo.settings?.backgroundColorHex, "#ffffff")
    XCTAssertEqual(demo.settings?.darkBackgroundColorHex, "#0d0f12")
  }
}
