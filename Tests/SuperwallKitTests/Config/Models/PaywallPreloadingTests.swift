//
//  PaywallPreloadingTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/02/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Testing
import Foundation

struct PaywallPreloadingTests {
  @Test
  func decodesScheduleWithMultipleSteps() throws {
    let json = """
    {
      "schedule": [
        {
          "placements": [
            { "placement": "onboarding" },
            { "placement": "feature_gate" }
          ],
          "delayMs": 0
        },
        {
          "placements": [
            { "placement": "settings" }
          ],
          "delayMs": 5000
        }
      ]
    }
    """.data(using: .utf8)!

    let preloading = try JSONDecoder().decode(PaywallPreloading.self, from: json)

    #expect(preloading.schedule.count == 2)

    let firstStep = preloading.schedule[0]
    #expect(firstStep.placements.count == 2)
    #expect(firstStep.placements[0].placement == "onboarding")
    #expect(firstStep.placements[1].placement == "feature_gate")
    #expect(firstStep.delay == 0)

    let secondStep = preloading.schedule[1]
    #expect(secondStep.placements.count == 1)
    #expect(secondStep.placements[0].placement == "settings")
    #expect(secondStep.delay == 5000)
  }

  @Test
  func decodesEmptySchedule() throws {
    let json = """
    {
      "schedule": []
    }
    """.data(using: .utf8)!

    let preloading = try JSONDecoder().decode(PaywallPreloading.self, from: json)

    #expect(preloading.schedule.isEmpty)
  }

  @Test
  func encodesAndDecodesRoundTrip() throws {
    let preloading = PaywallPreloading(
      schedule: [
        PreloadingStep(
          placements: [
            PreloadablePlacement(placement: "onboarding"),
            PreloadablePlacement(placement: "feature_gate")
          ],
          delay: 3000
        ),
        PreloadingStep(
          placements: [
            PreloadablePlacement(placement: "settings")
          ],
          delay: 10000
        )
      ]
    )

    let data = try JSONEncoder().encode(preloading)
    let decoded = try JSONDecoder().decode(PaywallPreloading.self, from: data)

    #expect(preloading == decoded)
  }

  @Test
  func delayMsKeyMapsToDelay() throws {
    let json = """
    {
      "placements": [{ "placement": "test" }],
      "delayMs": 2500
    }
    """.data(using: .utf8)!

    let step = try JSONDecoder().decode(PreloadingStep.self, from: json)

    #expect(step.delay == 2500)
    #expect(step.placements.first?.placement == "test")
  }
}
