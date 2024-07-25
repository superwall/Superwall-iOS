//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/07/2024.
//

import XCTest
@testable import SuperwallKit

final class SWWebViewLogicTests: XCTestCase {
  func test_chooseEndpoint_noEndpoints() {
    let outcome = SWWebViewLogic.chooseEndpoint(from: [])
    XCTAssertNil(outcome)
  }
  
  func test_chooseEndpoint_onlyOneEndpoint_zeroSum() {
    let endpoint = WebViewEndpoint.stub()
      .setting(\.percentage, to: 0)
    let outcome = SWWebViewLogic.chooseEndpoint(from: [endpoint])
    XCTAssertEqual(outcome, endpoint)
  }

  func test_chooseEndpoint_manyEndpoints_zeroSum() {
    let endpoint1 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 0)
    let endpoint2 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 0)
      .setting(\.url, to: URL(string:"https://bbc.com")!)
    let endpoint3 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 0)
      .setting(\.url, to: URL(string:"https://abc.com")!)
    let outcome = SWWebViewLogic.chooseEndpoint(
      from: [endpoint1, endpoint2, endpoint3]) { range in
        XCTAssertEqual(range, 0..<3)
        return 2
      }
    XCTAssertEqual(outcome, endpoint3)
  }

  func test_chooseEndpoint_oneActiveEndpoint_ChooseFirst() {
    let endpoint1 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 100)
    let endpoint2 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 0)
    let endpoint3 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 0)
    let outcome = SWWebViewLogic.chooseEndpoint(
      from: [endpoint1, endpoint2, endpoint3]
    )
    XCTAssertEqual(outcome, endpoint1)
  }

  func test_chooseEndpoint_99PercentSumEndpoint_chooseLast() {
    let endpoint1 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 33)
    let endpoint2 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 33)
    let endpoint3 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 33)
    let outcome = SWWebViewLogic.chooseEndpoint(
      from: [endpoint1, endpoint2, endpoint3]) { range in
        XCTAssertEqual(range, 0..<99)
        return 98.2
      }
    XCTAssertEqual(outcome, endpoint3)
  }

  func test_chooseEndpoint_99PercentSumEndpoint_chooseMiddle() {
    let endpoint1 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 33)
    let endpoint2 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 33)
    let endpoint3 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 33)
    let outcome = SWWebViewLogic.chooseEndpoint(
      from: [endpoint1, endpoint2, endpoint3]) { range in
        XCTAssertEqual(range, 0..<99)
        return 65
      }
    XCTAssertEqual(outcome, endpoint2)
  }

  func test_chooseEndpoint_99PercentSumEndpoint_chooseFirst() {
    let endpoint1 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 33)
    let endpoint2 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 33)
    let endpoint3 = WebViewEndpoint.stub()
      .setting(\.percentage, to: 33)
    let outcome = SWWebViewLogic.chooseEndpoint(
      from: [endpoint1, endpoint2, endpoint3]) { range in
        XCTAssertEqual(range, 0..<99)
        return 0
      }
    XCTAssertEqual(outcome, endpoint1)
  }
}
