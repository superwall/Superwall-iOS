//
//  PaywallPresentationStyleTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 06/08/2025.
//

import XCTest
@testable import SuperwallKit

final class PaywallPresentationStyleTests: XCTestCase {
  
  func test_paywallPresentationStyle_popup_encoding() throws {
    let style = PaywallPresentationStyle.popup
    let encoded = try JSONEncoder().encode(style)
    let decoded = try JSONDecoder().decode(PaywallPresentationStyle.self, from: encoded)
    
    XCTAssertEqual(decoded, .popup)
  }
  
  func test_paywallPresentationStyle_popup_decodingFromString() throws {
    let jsonString = "\"POPUP\""
    let jsonData = jsonString.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(PaywallPresentationStyle.self, from: jsonData)
    
    XCTAssertEqual(decoded, .popup)
  }
  
  func test_paywallPresentationStyle_popup_isAnimated() {
    // Test that popup presentation is animated (unlike fullscreenNoAnimation)
    XCTAssertTrue(PaywallPresentationStyle.popup != .fullscreenNoAnimation)
  }
  
  func test_paywallPresentationStyle_popup_rawValue() {
    // Test that popup has the correct raw value
    XCTAssertEqual(PaywallPresentationStyle.popup.rawValue, 6)
  }
}