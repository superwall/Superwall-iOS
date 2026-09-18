//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 17/03/2025.
//

import Foundation
import Testing
@testable import SuperwallKit

final class RedeemResponseTests {
  let successData = """
  {
    "codes": [
      {
        "status": "SUCCESS",
        "code": "redemption_8c7916a7-d48b-42c1-8eae-a58e0a57d37d",
        "redemptionInfo": {
          "ownership": {
            "type": "DEVICE",
            "deviceId": "$SuperwallDevice:24141E45-EDE8-4BD7-BCE9-A788228BCB0D"
          },
          "purchaserInfo": {
            "appUserId": "24141E45-EDE8-4BD7-BCE9-A788228BCB0D",
            "email": "asdasd@sdfsdf.com",
            "storeIdentifiers": {
              "store": "STRIPE",
              "stripeCustomerId": "cus_Ryex8C8944aFBa",
              "stripeSubscriptionIds": ["sub_123"]
            }
          },
          "paywallInfo": null,
          "entitlements": [
            {
              "identifier": "abc",
              "type": "SERVICE_LEVEL"
            }
          ]
        }
      }
    ],
    "customerInfo": {
      "subscriptions": [],
      "nonSubscriptions": [],
      "entitlements": [
        {
          "identifier": "abc",
          "type": "SERVICE_LEVEL"
        }
      ]
    }
  }
  """.data(using: .utf8)!

  let invalidCode = """
  {
    "codes": [
      {
        "status": "INVALID_CODE",
        "code": "redemption_8c7916a7-d48bs-42c1-8eae-a58e0a57d37d"
      }
    ],
    "customerInfo": {
      "subscriptions": [],
      "nonSubscriptions": [],
      "entitlements": []
    }
  }
  """.data(using: .utf8)!

  let expiredCode = """
  {
    "codes":[
      {
        "status":"CODE_EXPIRED",
        "code":"redemption_198a997f-ae38-45e8-9d7b-3e54be28fa08",
        "expired": {
          "resent":false,
          "obfuscatedEmail":null
        }
      }
    ],
    "customerInfo": {
      "subscriptions": [],
      "nonSubscriptions": [],
      "entitlements": []
    }
  }
  """.data(using: .utf8)!

  let successWithUserAttributes = """
  {
    "codes": [
      {
        "status": "SUCCESS",
        "code": "redemption_8c7916a7-d48b-42c1-8eae-a58e0a57d37d",
        "redemptionInfo": {
          "ownership": {
            "type": "APP_USER",
            "appUserId": "abc"
          },
          "purchaserInfo": {
            "appUserId": "abc",
            "email": "asdasd@sdfsdf.com",
            "storeIdentifiers": {
              "store": "STRIPE",
              "stripeCustomerId": "cus_Ryex8C8944aFBa",
              "stripeSubscriptionIds": ["sub_123"]
            }
          },
          "paywallInfo": null,
          "entitlements": [],
          "userAttributes": {
            "goal": "build_muscle",
            "experience": 3,
            "wantsReminders": true,
            "equipment": ["dumbbells", "bench"],
            "nickname": null
          }
        }
      }
    ],
    "customerInfo": {
      "subscriptions": [],
      "nonSubscriptions": [],
      "entitlements": []
    }
  }
  """.data(using: .utf8)!

  let successWithEmptyUserAttributes = """
  {
    "codes": [
      {
        "status": "SUCCESS",
        "code": "code",
        "redemptionInfo": {
          "ownership": {
            "type": "APP_USER",
            "appUserId": "abc"
          },
          "purchaserInfo": {
            "appUserId": "abc",
            "email": null,
            "storeIdentifiers": {
              "store": "STRIPE",
              "stripeCustomerId": "cus_Ryex8C8944aFBa",
              "stripeSubscriptionIds": ["sub_123"]
            }
          },
          "paywallInfo": null,
          "entitlements": [],
          "userAttributes": {}
        }
      }
    ],
    "customerInfo": {
      "subscriptions": [],
      "nonSubscriptions": [],
      "entitlements": []
    }
  }
  """.data(using: .utf8)!

  @Test("Decodes success JSON")
  func testSuccessRedeemResponseDecoding() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: successData)

    #expect(response.results.count == 1)
    #expect(response.results.first?.code == "redemption_8c7916a7-d48b-42c1-8eae-a58e0a57d37d")
    #expect(!response.customerInfo.entitlements.isEmpty)
  }

  @Test("All codes extracts the codes")
  func testAllCodesProperty() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: successData)

    let expectedCode = Redeemable(code: "redemption_8c7916a7-d48b-42c1-8eae-a58e0a57d37d", isFirstRedemption: false)
    #expect(response.allCodes == Set([expectedCode]))
  }

  @Test("Code is invalid")
  func testInvalidCode() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: invalidCode)
    switch response.results.first! {
    case .invalidCode(let code):
      #expect(code == "redemption_8c7916a7-d48bs-42c1-8eae-a58e0a57d37d")
    default:
      Issue.record("Incorrect result type")
    }
    #expect(response.customerInfo.entitlements.isEmpty)
  }

  @Test("Code is expired")
  func testExpiredCode() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: expiredCode)
    switch response.results.first! {
    case let .expiredCode(code, expiredInfo):
      #expect(code == "redemption_198a997f-ae38-45e8-9d7b-3e54be28fa08")
      #expect(expiredInfo.resent == false)
      #expect(expiredInfo.obfuscatedEmail == nil)
    default:
      Issue.record("Incorrect result type")
    }
    #expect(response.customerInfo.entitlements.isEmpty)
  }

  @Test("Decodes the user attributes collected on the web paywall funnel")
  func testDecodesUserAttributes() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: successWithUserAttributes)

    guard case let .success(_, redemptionInfo) = response.results.first else {
      Issue.record("Incorrect result type")
      return
    }
    let userAttributes = try #require(redemptionInfo.userAttributes)

    #expect(userAttributes["goal"] as? String == "build_muscle")
    #expect(userAttributes["experience"] as? Int == 3)
    #expect(userAttributes["wantsReminders"] as? Bool == true)
    #expect(userAttributes["equipment"] as? [String] == ["dumbbells", "bench"])
    #expect(userAttributes["nickname"] is NSNull)
  }

  @Test("User attributes are nil when the response omits them")
  func testUserAttributesAreNilWhenAbsent() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: successData)

    guard case let .success(_, redemptionInfo) = response.results.first else {
      Issue.record("Incorrect result type")
      return
    }
    #expect(redemptionInfo.userAttributes == nil)
  }

  @Test("User attributes are nil when the response sends an empty object")
  func testUserAttributesAreNilWhenEmpty() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: successWithEmptyUserAttributes)

    guard case let .success(_, redemptionInfo) = response.results.first else {
      Issue.record("Incorrect result type")
      return
    }
    #expect(redemptionInfo.userAttributes == nil)
  }

  @Test("User attributes survive an encode/decode round trip")
  func testUserAttributesRoundTrip() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: successWithUserAttributes)
    let result = try #require(response.results.first)

    let encoded = try JSONEncoder().encode(result)
    let decoded = try decoder.decode(RedemptionResult.self, from: encoded)

    guard case let .success(_, redemptionInfo) = decoded else {
      Issue.record("Incorrect result type")
      return
    }
    let userAttributes = try #require(redemptionInfo.userAttributes)

    #expect(userAttributes["goal"] as? String == "build_muscle")
    #expect(userAttributes["experience"] as? Int == 3)
    #expect(userAttributes["wantsReminders"] as? Bool == true)
    #expect(userAttributes["equipment"] as? [String] == ["dumbbells", "bench"])
  }

  @Test("User attributes are carried onto the Objective-C model")
  func testUserAttributesToObjc() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: successWithUserAttributes)
    let result = try #require(response.results.first)

    let objcResult = result.toObjc()
    let userAttributes = try #require(objcResult.redemptionInfo?.userAttributes)

    #expect(userAttributes["goal"] as? String == "build_muscle")
    #expect(userAttributes["equipment"] as? [String] == ["dumbbells", "bench"])
  }

  @Test("The Objective-C model keeps its initialiser that predates user attributes")
  func testObjcRedemptionInfoInitWithoutUserAttributes() throws {
    let redemptionInfo = RedemptionResultObjc.RedemptionInfo(
      ownership: RedemptionResultObjc.Ownership(appUserId: "abc"),
      purchaserInfo: RedemptionResultObjc.PurchaserInfo(
        appUserId: "abc",
        email: nil,
        storeIdentifiers: RedemptionResultObjc.StoreIdentifiers(
          stripeWithCustomerId: "cus_123",
          subscriptionIds: ["sub_123"]
        )
      ),
      paywallInfo: nil,
      entitlements: []
    )

    #expect(redemptionInfo.userAttributes == nil)
  }
}
