//
//  DevServerSettingsTests.swift
//  SuperwallKitTests
//

import XCTest
@testable import SuperwallKit

final class DevServerSettingsTests: XCTestCase {
  private func settings(_ json: String) throws -> DevServerSettings {
    return try JSONDecoder().decode(DevServerSettings.self, from: Data(json.utf8))
  }

  private func surface(_ json: String) throws -> DevServerSurface {
    return try JSONDecoder().decode(DevServerSurface.self, from: Data(json.utf8))
  }

  /// The block a current CLI serves for a paywall whose config.ts says nothing:
  /// every key the push stamps, at its default.
  func test_readsTheBlockAPaywallWithNoConfigGets() throws {
    let decoded = try settings("""
    {
      "presentation_style": { "type": "FULLSCREEN" },
      "feature_gating": "non_gated",
      "on_device_cache": true,
      "scroll_enabled": true,
      "game_controller_enabled": false,
      "introductory_offer_eligibility": "automatic"
    }
    """)

    XCTAssertEqual(decoded.presentationStyle, .fullscreen)
    XCTAssertEqual(decoded.featureGating, .nonGated)
    XCTAssertEqual(decoded.introOfferEligibility, .automatic)
    XCTAssertEqual(decoded.isScrollEnabled, true)
    XCTAssertNil(decoded.backgroundColorHex)
    XCTAssertNil(decoded.darkBackgroundColorHex)
  }

  func test_readsEveryStyleTheCliCanSend() throws {
    let cases: [(String, PaywallPresentationStyle)] = [
      ("{ \"type\": \"FULLSCREEN\" }", .fullscreen),
      ("{ \"type\": \"MODAL\" }", .modal),
      ("{ \"type\": \"PUSH\" }", .push),
      ("{ \"type\": \"NO_ANIMATION\" }", .fullscreenNoAnimation),
      (
        "{ \"type\": \"DRAWER\", \"height\": 60, \"corner_radius\": 15 }",
        .drawer(height: 60, cornerRadius: 15)
      ),
      (
        "{ \"type\": \"POPUP\", \"width\": 80, \"height\": 60, \"corner_radius\": 15 }",
        .popup(height: 60, width: 80, cornerRadius: 15)
      )
    ]

    for (json, expected) in cases {
      let decoded = try settings("{ \"presentation_style\": \(json) }")
      XCTAssertEqual(decoded.presentationStyle, expected, json)
    }
  }

  func test_readsGatedAndTheBackgroundHexes() throws {
    let decoded = try settings("""
    {
      "feature_gating": "gated",
      "background_color_hex": "#ffffff",
      "dark_background_color_hex": "#0d0f12"
    }
    """)

    XCTAssertEqual(decoded.featureGating, .gated)
    XCTAssertEqual(decoded.backgroundColorHex, "#ffffff")
    XCTAssertEqual(decoded.darkBackgroundColorHex, "#0d0f12")
  }

  /// Anything the block leaves out has to stay nil rather than default, since
  /// nil is what tells `Paywall.devServer` to inherit.
  func test_leavesEveryUnsaidSettingNil() throws {
    let decoded = try settings("{}")

    XCTAssertNil(decoded.presentationStyle)
    XCTAssertNil(decoded.featureGating)
    XCTAssertNil(decoded.introOfferEligibility)
    XCTAssertNil(decoded.isScrollEnabled)
    XCTAssertNil(decoded.backgroundColorHex)
    XCTAssertNil(decoded.darkBackgroundColorHex)
  }

  /// A newer CLI naming a style this SDK has never heard of costs the paywall
  /// its style, not the settings around it.
  func test_dropsAStyleItCannotNameAndKeepsTheRest() throws {
    let decoded = try settings("""
    {
      "presentation_style": { "type": "HOLOGRAM" },
      "feature_gating": "gated",
      "scroll_enabled": false
    }
    """)

    XCTAssertNil(decoded.presentationStyle)
    XCTAssertEqual(decoded.featureGating, .gated)
    XCTAssertEqual(decoded.isScrollEnabled, false)
  }

  /// Geometry the SDK can't trust is treated the same way: the CLI resolves
  /// height and radius before serving them, so a partial one is unreadable
  /// rather than something to guess a default for.
  func test_dropsGeometryItCannotTrust() throws {
    XCTAssertNil(
      try settings("{ \"presentation_style\": { \"type\": \"DRAWER\" } }").presentationStyle
    )
    XCTAssertNil(
      try settings("{ \"presentation_style\": { \"type\": \"POPUP\", \"height\": 60 } }")
        .presentationStyle
    )
  }

  func test_readsEveryEligibilityTheCliCanSend() throws {
    let cases: [(String, IntroOfferEligibility)] = [
      ("automatic", .automatic),
      ("always_eligible", .eligible),
      ("always_ineligible", .ineligible)
    ]

    for (wire, expected) in cases {
      let decoded = try settings("{ \"introductory_offer_eligibility\": \"\(wire)\" }")
      XCTAssertEqual(decoded.introOfferEligibility, expected, wire)
    }
  }

  /// A value named by a newer CLI costs that setting alone, the same way an
  /// unreadable style does — the paywall falls back to its published gating
  /// and eligibility, and keeps everything else its config.ts declares.
  func test_dropsAGatingOrEligibilityItCannotNameAndKeepsTheRest() throws {
    let decoded = try settings("""
    {
      "feature_gating": "sometimes",
      "introductory_offer_eligibility": "maybe",
      "scroll_enabled": false,
      "background_color_hex": "#ffffff"
    }
    """)

    XCTAssertNil(decoded.featureGating)
    XCTAssertNil(decoded.introOfferEligibility)
    XCTAssertEqual(decoded.isScrollEnabled, false)
    XCTAssertEqual(decoded.backgroundColorHex, "#ffffff")
  }

  func test_aSurfaceFromAnOlderDevServerCarriesNoSettings() throws {
    let decoded = try surface("""
    { "kind": "paywall", "id": "pro", "url": "/preview/paywall/pro" }
    """)

    XCTAssertNil(decoded.settings)
  }

  /// A setting the SDK can't name costs that setting alone: the surface keeps
  /// its local code and the rest of the block.
  func test_keepsASurfaceWhoseSettingIsUnnameable() throws {
    let decoded = try surface("""
    {
      "kind": "paywall",
      "id": "pro",
      "url": "/preview/paywall/pro",
      "settings": { "feature_gating": "sometimes", "scroll_enabled": false }
    }
    """)

    XCTAssertEqual(decoded.id, "pro")
    XCTAssertNil(decoded.settings?.featureGating)
    XCTAssertEqual(decoded.settings?.isScrollEnabled, false)
  }

  /// A block the SDK can't decode at all — a key of the wrong type rather than
  /// a value it can't name — is still dropped whole by the `try?` in
  /// `DevServerSurface`, and still costs the surface only its settings: it
  /// serves its local code and presents as its published version does.
  func test_keepsASurfaceWhoseSettingsBlockIsMalformed() throws {
    let decoded = try surface("""
    {
      "kind": "paywall",
      "id": "pro",
      "url": "/preview/paywall/pro",
      "settings": { "scroll_enabled": "yes" }
    }
    """)

    XCTAssertEqual(decoded.id, "pro")
    XCTAssertNil(decoded.settings)
  }

  func test_stillRefusesASurfaceMissingItsIdentity() throws {
    XCTAssertThrowsError(try surface("""
    { "kind": "paywall", "url": "/preview/paywall/pro" }
    """))
  }
}
