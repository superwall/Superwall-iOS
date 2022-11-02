//
//  SWDebugManagerLogicTests.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

class SWDebugManagerLogicTests: XCTestCase {
  func testGetQueryItemValue_noQueryItems() {
    // Given
    let url = URL(string: "https://google.com")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .token)

    // Then
    XCTAssertNil(value)
  }

  func testGetQueryItemValue_superwallDebug() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .superwallDebug)

    // Then
    XCTAssertEqual(value, "true")
  }

  func testGetQueryItemValue_superwallDebug_nil() {
    // Given
    let url = URL(string: "myapp://?paywall_id=123")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .superwallDebug)

    // Then
    XCTAssertNil(value)
  }

  func testGetQueryItemValue_paywallId() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&paywall_id=123")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .paywallId)

    // Then
    XCTAssertEqual(value, "123")
  }

  func testGetQueryItemValue_paywallId_nil() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .paywallId)

    // Then
    XCTAssertNil(value)
  }

  func testGetQueryItemValue_token() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&paywall_id=123&token=abcdef123")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .token)

    // Then
    XCTAssertEqual(value, "abcdef123")
  }

  func testGetQueryItemValue_token_nil() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&paywall_id=123")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .token)

    // Then
    XCTAssertNil(value)
  }
}
