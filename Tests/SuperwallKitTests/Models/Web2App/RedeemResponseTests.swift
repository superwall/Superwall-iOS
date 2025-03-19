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
            "type": "device",
            "deviceId": "$SuperwallDevice:24141E45-EDE8-4BD7-BCE9-A788228BCB0D"
          },
          "purchaserInfo": {
            "appUserId": "24141E45-EDE8-4BD7-BCE9-A788228BCB0D",
            "email": "asdasd@sdfsdf.com",
            "storeIdentifiers": {
              "store": "STRIPE",
              "stripeSubscriptionId": "sub_1R3awqBitwqMmwU0FEHl0ZJ6"
            }
          },
          "paywallInfo": null,
          "entitlements": [
            {
              "identifier": "…",
              "type": "SERVICE_LEVEL"
            }
          ]
        }
      }
    ],
    "entitlements": [
      {
        "identifier": "…",
        "type": "SERVICE_LEVEL"
      }
    ]
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
    "entitlements": []
  }
  """.data(using: .utf8)!

  @Test("Decodes success JSON")
  func testSuccessRedeemResponseDecoding() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(RedeemResponse.self, from: successData)

    #expect(response.results.count == 1)
    #expect(response.results.first?.code == "redemption_8c7916a7-d48b-42c1-8eae-a58e0a57d37d")
    #expect(response.entitlements.isEmpty)
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
    #expect(response.entitlements.isEmpty)
  }
}
