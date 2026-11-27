//
//  MacBuildSignatureTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/11/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Foundation
import Testing

@Suite
struct MacBuildSignatureTests {
  @Test
  func testFlightSignatureIsSandbox() {
    let isSandbox = MacBuildSignature.isSandbox(allowsDebugger: false) { $0 == .testFlight }
    #expect(isSandbox)
  }

  @Test
  func developmentSignatureIsSandbox() {
    let isSandbox = MacBuildSignature.isSandbox(allowsDebugger: false) { $0 == .development }
    #expect(isSandbox)
  }

  @Test
  func appThatAllowsTheDebuggerIsSandbox() {
    let isSandbox = MacBuildSignature.isSandbox(allowsDebugger: true) { _ in false }
    #expect(isSandbox)
  }

  @Test
  func otherSignatureIsNotSandbox() {
    let isSandbox = MacBuildSignature.isSandbox(allowsDebugger: false) { _ in false }
    #expect(!isSandbox)
  }
}
