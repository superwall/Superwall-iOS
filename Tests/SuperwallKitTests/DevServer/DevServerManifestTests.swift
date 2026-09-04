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
}
