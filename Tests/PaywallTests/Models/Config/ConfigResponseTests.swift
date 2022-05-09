import XCTest
@testable import Paywall
import CoreMedia

// swiftlint:disable all

let response = #"""
{
  "triggers": [
    {
      "trigger_version": "V2",
      "event_name": "opened_application",
      "rules": [
        {
          "experiment_id": "2",
          "expression": "name == jake",
          "assigned": false,
          "variant": {
            "variant_id": "7",
            "variant_type": "HOLDOUT"
          }
        },
        {
          "experiment_id": "2",
          "expression": null,
          "assigned": false,
          "variant": {
            "variant_id": "6",
            "variant_type": "TREATMENT",
            "paywall_identifier": "omnis-id-ab"
          }
        }
      ]
    },
    {
      "trigger_version": "V1",
      "event_name": "other_event"
    }
  ],
  "product_identifier_groups": [],
  "paywalls": [],
  "log_level": 10,
  "postback": {
    "delay": 5000,
    "products": []
  },
  "localization": {
    "locales": [{
      "locale": "en_US"
    }]
  },
  "tests": {
    "dns_resolution": []
  }
}
"""#

final class ConfigTypeTests: XCTestCase {
  func testParseConfig() throws {
    let parsedResponse = try! JSONDecoder.endpoint.decode(
      Config.self,
      from: response.data(using: .utf8)!
    )
    print(parsedResponse)

    guard let firstTrigger = parsedResponse.triggers.filter({ $0.eventName == "opened_application" }).first
    else {
      return XCTFail("opened_application trigger not found")
    }

    switch firstTrigger.triggerVersion {
    case .v1:
      throw TestError.init("Expecting V2")
    case .v2(let v2):
      let firstRule = v2.rules[0]
      XCTAssertEqual(firstRule.isAssigned, false)
      XCTAssertEqual(firstRule.expression, "name == jake")
      XCTAssertEqual(firstRule.experimentId, "2")

      switch firstRule.variant {
      case .treatment:
        throw TestError.init("Expecting Holdout")
      case .holdout(let holdout):
        XCTAssertEqual(holdout.variantId, "7")
      }
      let secondRule = v2.rules[1]

      switch secondRule.variant {
      case .holdout:
        throw TestError.init("Expecting holdout")
      case .treatment(let treatment):
        XCTAssertEqual(treatment.paywallIdentifier, "omnis-id-ab")
        XCTAssertEqual(treatment.variantId, "6")
      }
    }

    guard let secondTrigger = parsedResponse.triggers.filter({ $0.eventName == "other_event" }).first
    else {
      return XCTFail("opened_application trigger not found")
    }

    switch secondTrigger.triggerVersion {
    case .v2:
      throw TestError.init("Expecting V1")
    default:
      break
    }
  }
}
