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

  @Test func getQueryItemValue_trialState() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&trial_state=eligible")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .trialState)

    // Then
    #expect(value == "eligible")
  }

  @Test func getQueryItemValue_appearance() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&appearance=dark")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .appearance)

    // Then
    #expect(value == "dark")
  }

  @Test func getQueryItemValue_locale() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&locale=de")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .locale)

    // Then
    #expect(value == "de")
  }

  @Test func getQueryItemValue_present() {
    // Given
    let url = URL(string: "myapp://?superwall_debug=true&present=true")!

    // When
    let value = SWDebugManagerLogic.getQueryItemValue(fromUrl: url, withName: .present)

    // Then
    #expect(value == "true")
  }
}
