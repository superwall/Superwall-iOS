//
//  InAppReceiptTests.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//
// swiftlint:disable all

import XCTest
@testable import Superwall

class InAppReceiptTests: XCTestCase {
  // MARK: - Test processing of receipt data
  func testCrashReceipt_hasntPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.crashReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: "CYCLEMAPS_PREMIUM")
    XCTAssertFalse(hasPurchased)
  }

  func testNewReceipt_hasPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.newReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: "CYCLEMAPS_PREMIUM")
    XCTAssertTrue(hasPurchased)
  }

  func testNewReceipt_hasntPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.newReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: "OTHER_ID")
    XCTAssertFalse(hasPurchased)
  }

  func testLegacyReceipt_hasPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.legacyReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: "com.nutcallalert.inapp.optimum")
    XCTAssertTrue(hasPurchased)
  }

  func testLegacyReceipt_hasntPurchased() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.legacyReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: "otherId")
    XCTAssertFalse(hasPurchased)
  }

  func testPurchasedProductIds() {
    let getReceiptData: () -> Data = {
      return MockReceiptData.legacyReceipt
    }
    let inAppReceipt = InAppReceipt(getReceiptData: getReceiptData)
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: "com.nutcallalert.inapp.optimum")
    XCTAssertTrue(hasPurchased)
    XCTAssertEqual(inAppReceipt.purchasedProductIds, Set(["com.nutcallalert.inapp.pro", "com.nutcallalert.inapp.optimum", "com.nutcallalert.inapp.lite"]))
  }

  // MARK: - hasPurchasedInSubscriptionGroupOfProduct

  func test_purchasedWithinSubscriptionGroupId() {
    let storeKitManager = StoreKitManager()
    let subscriptionGroupId = "abc"

    let proProductId = "com.nutcallalert.inapp.pro"
    let proProduct = MockSkProduct(
      productIdentifier: proProductId,
      subscriptionGroupIdentifier: subscriptionGroupId
    )

    let notYetPurchasedProductId = "com.nutcallalert.inapp.notyetpurchased"
    let notYetPurchasedProduct = MockSkProduct(
      productIdentifier: notYetPurchasedProductId,
      subscriptionGroupIdentifier: subscriptionGroupId
    )
    storeKitManager.productsById = [
      proProductId: proProduct,
      notYetPurchasedProductId: notYetPurchasedProduct
    ]
    let getReceiptData: () -> Data = {
      return MockReceiptData.legacyReceipt
    }
    let inAppReceipt = InAppReceipt(
      getReceiptData: getReceiptData,
      storeKitManager: storeKitManager
    )
    inAppReceipt.loadSubscriptionGroupIds()
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: notYetPurchasedProductId)
    XCTAssertTrue(hasPurchased)
    XCTAssertEqual(inAppReceipt.purchasedProductIds, Set(["com.nutcallalert.inapp.pro", "com.nutcallalert.inapp.optimum", "com.nutcallalert.inapp.lite"]))
  }

  func test_hasntPurchasedWithinSubscriptionGroupId() {
    let storeKitManager = StoreKitManager()
    let subscriptionGroupId1 = "abc"
    let subscriptionGroupId2 = "cde"

    let proProductId = "com.nutcallalert.inapp.pro"
    let proProduct = MockSkProduct(
      productIdentifier: proProductId,
      subscriptionGroupIdentifier: subscriptionGroupId1
    )

    let notYetPurchasedProductId = "com.nutcallalert.inapp.notyetpurchased"
    let notYetPurchasedProduct = MockSkProduct(
      productIdentifier: notYetPurchasedProductId,
      subscriptionGroupIdentifier: subscriptionGroupId2
    )
    storeKitManager.productsById = [
      proProductId: proProduct,
      notYetPurchasedProductId: notYetPurchasedProduct
    ]
    let getReceiptData: () -> Data = {
      return MockReceiptData.legacyReceipt
    }
    let inAppReceipt = InAppReceipt(
      getReceiptData: getReceiptData,
      storeKitManager: storeKitManager
    )
    inAppReceipt.loadSubscriptionGroupIds()
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: notYetPurchasedProductId)
    XCTAssertFalse(hasPurchased)
  }

  func test_failedToLoadSubscriptionGroupIds() {
    let storeKitManager = StoreKitManager()
    let subscriptionGroupId1 = "abc"

    let proProductId = "com.nutcallalert.inapp.pro"
    let proProduct = MockSkProduct(
      productIdentifier: proProductId,
      subscriptionGroupIdentifier: subscriptionGroupId1
    )

    let notYetPurchasedProductId = "com.nutcallalert.inapp.notyetpurchased"
    let notYetPurchasedProduct = MockSkProduct(
      productIdentifier: notYetPurchasedProductId,
      subscriptionGroupIdentifier: subscriptionGroupId1
    )
    storeKitManager.productsById = [
      proProductId: proProduct,
      notYetPurchasedProductId: notYetPurchasedProduct
    ]
    let getReceiptData: () -> Data = {
      return MockReceiptData.legacyReceipt
    }
    let inAppReceipt = InAppReceipt(
      getReceiptData: getReceiptData,
      storeKitManager: storeKitManager
    )
    inAppReceipt.failedToLoadPurchasedProducts()
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: notYetPurchasedProductId)
    XCTAssertFalse(hasPurchased)
  }

  func test_nonAutorenewingSubscription() {
    let storeKitManager = StoreKitManager()
    let subscriptionGroupId1 = "abc"

    let proProductId = "com.nutcallalert.inapp.pro"
    let proProduct = MockSkProduct(
      productIdentifier: proProductId
    )

    storeKitManager.productsById = [
      proProductId: proProduct
    ]
    let getReceiptData: () -> Data = {
      return MockReceiptData.legacyReceipt
    }
    let inAppReceipt = InAppReceipt(
      getReceiptData: getReceiptData,
      storeKitManager: storeKitManager
    )
    inAppReceipt.loadSubscriptionGroupIds()
    let hasPurchased = inAppReceipt.hasPurchasedInSubscriptionGroupOfProduct(withId: proProductId)
    XCTAssertTrue(hasPurchased)
  }
}

