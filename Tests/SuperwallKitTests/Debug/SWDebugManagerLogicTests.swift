//
//  SWDebugManagerLogicTests.swift
//
//
//  Created by Yusuf Tör on 20/04/2022.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

struct SWDebugManagerLogicTests {
  @Test func getQueryItemValue_noQueryItems() {
    // Given
    let url = URL(string: "https://google.com")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .token)

    // Then
    #expect(value == nil)
  }

  @Test func getQueryItemValue_superwallDebug() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .superwallDebug)

    // Then
    #expect(value == "true")
  }

  @Test func getQueryItemValue_superwallDebug_nil() {
    // Given
    let url = URL(string: "myapp://?paywall_id=123")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .superwallDebug)

    // Then
    #expect(value == nil)
  }

  @Test func getQueryItemValue_paywallId() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&paywall_id=123")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .paywallId)

    // Then
    #expect(value == "123")
  }

  @Test func getQueryItemValue_paywallId_nil() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .paywallId)

    // Then
    #expect(value == nil)
  }

  @Test func getQueryItemValue_token() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&paywall_id=123&token=abcdef123")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .token)

    // Then
    #expect(value == "abcdef123")
  }

  @Test func getQueryItemValue_token_nil() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&paywall_id=123")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .token)

    // Then
    #expect(value == nil)
  }
}
