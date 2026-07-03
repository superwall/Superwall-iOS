//
//  AppStoreProductTests.swift
//  SuperwallKitTests
//

@testable import SuperwallKit
import Testing
import Foundation

// swiftlint:disable all

struct AppStoreProductTests {
  @Test
  func decode_withMonthlyBillingPlan() throws {
    let json = #"""
    {
      "productIdentifier": "com.app.annual",
      "store": "APP_STORE",
      "billingPlanType": "MONTHLY"
    }
    """#.data(using: .utf8)!

    let product = try JSONDecoder().decode(AppStoreProduct.self, from: json)

    #expect(product.id == "com.app.annual")
    #expect(product.billingPlanType == .monthly)
  }

  @Test
  func decode_withUpFrontBillingPlan() throws {
    let json = #"""
    {
      "productIdentifier": "com.app.annual",
      "store": "APP_STORE",
      "billingPlanType": "UP_FRONT"
    }
    """#.data(using: .utf8)!

    let product = try JSONDecoder().decode(AppStoreProduct.self, from: json)

    #expect(product.billingPlanType == .upFront)
  }

  @Test
  func decode_withoutBillingPlan_legacyCompatible() throws {
    let json = #"""
    {
      "productIdentifier": "com.app.basic",
      "store": "APP_STORE"
    }
    """#.data(using: .utf8)!

    let product = try JSONDecoder().decode(AppStoreProduct.self, from: json)

    #expect(product.id == "com.app.basic")
    #expect(product.billingPlanType == nil)
  }

  @Test
  func encode_roundTripsBillingPlan() throws {
    let original = AppStoreProduct(id: "com.app.annual", billingPlanType: .monthly)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(AppStoreProduct.self, from: data)

    #expect(decoded.id == original.id)
    #expect(decoded.billingPlanType == original.billingPlanType)
  }

  @Test
  func equality_distinguishesByBillingPlan() {
    let upfront = AppStoreProduct(id: "com.app.annual", billingPlanType: .upFront)
    let monthly = AppStoreProduct(id: "com.app.annual", billingPlanType: .monthly)
    let nilPlan = AppStoreProduct(id: "com.app.annual", billingPlanType: nil)

    #expect(!upfront.isEqual(monthly))
    #expect(!upfront.isEqual(nilPlan))
    #expect(upfront.isEqual(AppStoreProduct(id: "com.app.annual", billingPlanType: .upFront)))
  }
}
