//
//  PrioritizedCampaignTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/02/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Testing
import Foundation

struct PrioritizedCampaignTests {
  private let togglesJson = """
  [
    { "key": "enable_expression_params", "enabled": true },
    { "key": "enable_postback", "enabled": true },
    { "key": "disable_verbose_events", "enabled": true },
    { "key": "enable_multiple_paywall_urls", "enabled": false },
    { "key": "enable_config_refresh_v2", "enabled": false }
  ]
  """

  @Test
  func decodesConfigWithPrioritizedCampaignId() throws {
    let json = """
    {
      "buildId": "abc",
      "triggerOptions": [],
      "paywallResponses": [],
      "logLevel": 0,
      "localization": { "locales": [] },
      "appSessionTimeoutMs": 3600000,
      "toggles": \(togglesJson),
      "disablePreload": { "all": false, "triggers": [] },
      "prioritizedCampaignId": "42"
    }
    """.data(using: .utf8)!

    let config = try JSONDecoder().decode(Config.self, from: json)

    #expect(config.prioritizedCampaignId == "42")
  }

  @Test
  func decodesConfigWithNullPrioritizedCampaignId() throws {
    let json = """
    {
      "buildId": "abc",
      "triggerOptions": [],
      "paywallResponses": [],
      "logLevel": 0,
      "localization": { "locales": [] },
      "appSessionTimeoutMs": 3600000,
      "toggles": \(togglesJson),
      "disablePreload": { "all": false, "triggers": [] },
      "prioritizedCampaignId": null
    }
    """.data(using: .utf8)!

    let config = try JSONDecoder().decode(Config.self, from: json)

    #expect(config.prioritizedCampaignId == nil)
  }

  @Test
  func decodesConfigWithoutPrioritizedCampaignId() throws {
    let json = """
    {
      "buildId": "abc",
      "triggerOptions": [],
      "paywallResponses": [],
      "logLevel": 0,
      "localization": { "locales": [] },
      "appSessionTimeoutMs": 3600000,
      "toggles": \(togglesJson),
      "disablePreload": { "all": false, "triggers": [] }
    }
    """.data(using: .utf8)!

    let config = try JSONDecoder().decode(Config.self, from: json)

    #expect(config.prioritizedCampaignId == nil)
  }

  @Test
  func encodesAndDecodesRoundTripWithPrioritizedCampaignId() throws {
    var config: Config = .stub()
    config.prioritizedCampaignId = "99"

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(Config.self, from: data)

    #expect(decoded.prioritizedCampaignId == "99")
  }

  @Test
  func encodesAndDecodesRoundTripWithNilPrioritizedCampaignId() throws {
    var config: Config = .stub()
    config.prioritizedCampaignId = nil

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(Config.self, from: data)

    #expect(decoded.prioritizedCampaignId == nil)
  }
}
