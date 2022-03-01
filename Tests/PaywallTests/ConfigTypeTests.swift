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
    "tests": {
        "dns_resolution": []
    }
}
"""#

final class ConfigTypeTests: XCTestCase {
  func testParseConfig() throws {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let parsedResponse = try! decoder.decode(ConfigResponse.self, from: response.data(using: .utf8)!)
    print(parsedResponse)

    let firstTrigger = parsedResponse.triggers[0]
    XCTAssertEqual(firstTrigger.eventName, "opened_application")

    switch firstTrigger.triggerVersion {
    case .V1:
      throw TestError.init("Expecting V2")
    case .V2(let v2):
      let firstRule = v2.rules[0]
      XCTAssertEqual(firstRule.assigned, false)
      XCTAssertEqual(firstRule.expression, "name == jake")
      XCTAssertEqual(firstRule.experimentId, "2")

      switch firstRule.variant {
      case .Treatment:
        throw TestError.init("Expecting Holdout")
      case .Holdout(let holdout):
        XCTAssertEqual(holdout.variantId, "7")
      }
      let secondRule = v2.rules[1]

      switch secondRule.variant {
      case .Holdout:
        throw TestError.init("Expecting holdout")
      case .Treatment(let treatment):
        XCTAssertEqual(treatment.paywallIdentifier, "omnis-id-ab")
        XCTAssertEqual(treatment.variantId, "6")
      }
    }
    let secondTrigger = parsedResponse.triggers[1]
    XCTAssertEqual(secondTrigger.eventName, "other_event")

    switch secondTrigger.triggerVersion {
    case .V2:
      throw TestError.init("Expecting V1")
    default:
      break
    }
  }
}
