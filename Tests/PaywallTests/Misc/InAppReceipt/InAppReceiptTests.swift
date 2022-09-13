//
//  InAppReceiptTests.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//
/*
import XCTest
@testable import Paywall

class InAppReceiptTests: XCTestCase {
  func testCrashReceipt_hasntPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.crashReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.
    hasPurchased(productId: "CYCLEMAPS_PREMIUM")
    XCTAssertFalse(hasPurchased)
  }

  func testNewReceipt_hasPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.newReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchased(productId: "CYCLEMAPS_PREMIUM")
    XCTAssertTrue(hasPurchased)
  }

  func testNewReceipt_hasntPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.newReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchased(productId: "OTHER_ID")
    XCTAssertFalse(hasPurchased)
  }

  func testLegacyReceipt_hasPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.legacyReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchased(productId: "com.nutcallalert.inapp.optimum")
    XCTAssertTrue(hasPurchased)
  }

  func testLegacyReceipt_hasntPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.legacyReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchased(productId: "otherId")
    XCTAssertFalse(hasPurchased)
  }
}
*/
