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
    products: [String: String]? = nil,
    presentation: String? = nil
  ) -> DevServerSurface {
    let json = """
    {
      "kind": "paywall",
      "id": "\(id)",
      "url": "/preview/paywall/\(id)",
      \(paywallId.map { "\"paywallId\": \"\($0)\"," } ?? "")
      \(identifier.map { "\"identifier\": \"\($0)\"," } ?? "")
      \(presentation.map { "\"presentation\": \($0)," } ?? "")
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

  func test_presentsFullscreenWhenTheConfigSaysNothing() {
    let paywall = Paywall.devServer(surface: surface(), url: url)
    XCTAssertEqual(paywall.presentation.style, .fullscreen)
  }

  func test_usesThePresentationStyleTheConfigDeclares() {
    let modal = Paywall.devServer(
      surface: surface(presentation: #"{"style": "modal"}"#),
      url: url
    )
    XCTAssertEqual(modal.presentation.style, .modal)

    let drawer = Paywall.devServer(
      surface: surface(presentation: #"{"style": "drawer", "drawer": {"height": 420, "cornerRadius": 24}}"#),
      url: url
    )
    XCTAssertEqual(drawer.presentation.style, .drawer(height: 420, cornerRadius: 24))

    let popup = Paywall.devServer(
      surface: surface(presentation: #"{"style": "popup", "popup": {"width": 300, "height": 500, "cornerRadius": 16}}"#),
      url: url
    )
    XCTAssertEqual(popup.presentation.style, .popup(height: 500, width: 300, cornerRadius: 16))
  }

  func test_fallsBackToFullscreenWhenAStyleIsUnknown() {
    let unknown = Paywall.devServer(
      surface: surface(presentation: #"{"style": "hologram"}"#),
      url: url
    )
    XCTAssertEqual(unknown.presentation.style, .fullscreen)
  }

  // MARK: - Partly specified geometry

  func test_drawerWithoutGeometryUsesTheDocumentedDefaults() {
    let drawer = Paywall.devServer(
      surface: surface(presentation: #"{"style": "drawer"}"#),
      url: url
    )
    // 70% of the screen is what PaywallPresentationStyle.drawer documents.
    XCTAssertEqual(drawer.presentation.style, .drawer(height: 70, cornerRadius: 0))
  }

  func test_drawerKeepsTheValuesItDoesNameAndDefaultsTheRest() {
    let heightOnly = Paywall.devServer(
      surface: surface(presentation: #"{"style": "drawer", "drawer": {"height": 420}}"#),
      url: url
    )
    XCTAssertEqual(heightOnly.presentation.style, .drawer(height: 420, cornerRadius: 0))

    let radiusOnly = Paywall.devServer(
      surface: surface(presentation: #"{"style": "drawer", "drawer": {"cornerRadius": 24}}"#),
      url: url
    )
    XCTAssertEqual(radiusOnly.presentation.style, .drawer(height: 70, cornerRadius: 24))
  }

  func test_popupWithoutBothDimensionsFallsBackToFullscreen() {
    // A popup has no documented default size, so a partial one can't be honoured.
    let heightOnly = Paywall.devServer(
      surface: surface(presentation: #"{"style": "popup", "popup": {"height": 500}}"#),
      url: url
    )
    XCTAssertEqual(heightOnly.presentation.style, .fullscreen)

    let noGeometry = Paywall.devServer(
      surface: surface(presentation: #"{"style": "popup"}"#),
      url: url
    )
    XCTAssertEqual(noGeometry.presentation.style, .fullscreen)
  }

  func test_popupWithBothDimensionsDefaultsOnlyItsRadius() {
    let popup = Paywall.devServer(
      surface: surface(presentation: #"{"style": "popup", "popup": {"width": 300, "height": 500}}"#),
      url: url
    )
    XCTAssertEqual(popup.presentation.style, .popup(height: 500, width: 300, cornerRadius: 0))
  }
}
