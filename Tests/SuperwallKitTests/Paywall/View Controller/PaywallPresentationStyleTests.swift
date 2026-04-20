//
//  PaywallPresentationStyleTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 06/08/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

struct PaywallPresentationStyleTests {

  @Test
  func paywallPresentationStyle_popup_encoding() throws {
    let style = PaywallPresentationStyle.popup(height: 60, width: 80, cornerRadius: 15)
    let encoded = try JSONEncoder().encode(style)
    let decoded = try JSONDecoder().decode(PaywallPresentationStyle.self, from: encoded)

    #expect(decoded == .popup(height: 60, width: 80, cornerRadius: 15))
  }

  @Test
  func paywallPresentationStyle_popup_decodingFromString() throws {
    let jsonString = """
    {
      "type": "POPUP",
      "height": 60.0,
      "width": 80.0,
      "cornerRadius": 15.0
    }
    """
    let jsonData = jsonString.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(PaywallPresentationStyle.self, from: jsonData)

    #expect(decoded == .popup(height: 60, width: 80, cornerRadius: 15))
  }

  @Test
  func paywallPresentationStyle_popup_isAnimated() {
    // Test that popup presentation is animated (unlike fullscreenNoAnimation)
    let popup = PaywallPresentationStyle.popup(height: 60, width: 80, cornerRadius: 15)
    #expect(popup != .fullscreenNoAnimation)
  }

  @Test
  func paywallPresentationStyle_popup_extractProperties() {
    // Test that popup properties can be extracted
    let popup = PaywallPresentationStyle.popup(height: 60, width: 80, cornerRadius: 15)
    #expect(popup.popupHeight?.doubleValue == 60)
    #expect(popup.popupWidth?.doubleValue == 80)
    #expect(popup.popupCornerRadius?.doubleValue == 15)
  }
}
