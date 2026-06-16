//
//  MMPMatchResponseTests.swift
//  SuperwallKit
//
//  Tests that `MMPMatchResponse` decodes the shapes the backend `/api/match`
//  endpoint can actually return.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

@Suite
struct MMPMatchResponseTests {
  private func decode(_ json: String) throws -> MMPMatchResponse {
    try JSONDecoder.subscriptionsApi.decode(MMPMatchResponse.self, from: Data(json.utf8))
  }

  /// `queryParams` values can be arrays when a query key appears more than once
  /// in the click URL. This must not fail the whole decode.
  @Test
  func decodes_queryParamsWithDuplicatedKeyArray() throws {
    let json = """
    {
      "matched": true,
      "confidence": "high",
      "matchScore": 95,
      "clickId": 123,
      "linkId": "link_1",
      "network": "meta",
      "redirectUrl": "https://example.com",
      "queryParams": { "placement": ["a", "b"], "utm_source": "meta" },
      "acquisitionAttributes": { "acquisition_source": "meta" },
      "matchedAt": "2026-06-16T00:00:00Z",
      "breakdown": { "reason": "matched" }
    }
    """

    let response = try decode(json)

    #expect(response.matched == true)
    #expect(response.confidence == .high)
    #expect(response.queryParams?["placement"]?.array?.count == 2)
    #expect(response.queryParams?["utm_source"]?.string == "meta")
    #expect(response.acquisitionAttributes?["acquisition_source"]?.string == "meta")
  }

  /// An unrecognised `confidence` value (e.g. a future tier) should degrade to
  /// `nil` rather than failing the entire response decode.
  @Test
  func decodes_unknownConfidenceAsNil() throws {
    let json = """
    {
      "matched": true,
      "confidence": "very_high",
      "matchScore": 110
    }
    """

    let response = try decode(json)

    #expect(response.matched == true)
    #expect(response.confidence == nil)
    #expect(response.matchScore == 110)
  }

  @Test
  func decodes_knownConfidenceLevels() throws {
    #expect(try decode(#"{ "matched": true, "confidence": "high" }"#).confidence == .high)
    #expect(try decode(#"{ "matched": true, "confidence": "medium" }"#).confidence == .medium)
    #expect(try decode(#"{ "matched": true, "confidence": "low" }"#).confidence == .low)
  }

  /// The unmatched response shape: all nullable fields are `null`, with only a
  /// `breakdown.reason` explaining why.
  @Test
  func decodes_unmatchedResponseWithNullFields() throws {
    let json = """
    {
      "matched": false,
      "confidence": null,
      "matchScore": null,
      "clickId": null,
      "linkId": null,
      "network": null,
      "redirectUrl": null,
      "queryParams": null,
      "acquisitionAttributes": null,
      "matchedAt": null,
      "breakdown": { "reason": "below_threshold", "candidateCount": 0 }
    }
    """

    let response = try decode(json)

    #expect(response.matched == false)
    #expect(response.confidence == nil)
    #expect(response.matchScore == nil)
    #expect(response.queryParams == nil)
    #expect(response.acquisitionAttributes == nil)
    #expect(response.breakdown?["reason"]?.string == "below_threshold")
  }
}
