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
}
