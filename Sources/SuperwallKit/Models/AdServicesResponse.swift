//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/11/2024.
//

import Foundation

struct AdServicesResponse: Decodable {
  // Backend (`paywall-next:/apple-search-ads/token`) returns
  // `{ status: "ok", attribution: {...} }` on success. Error states come
  // back as non-2xx with `{ status: "error", error: "..." }`, but those are
  // thrown by `CustomURLSession`'s Task.retrying before we ever decode the
  // body, so we only model the success shape here.
  let attribution: [String: JSON]
}

// MARK: - MMP Attribution

struct MMPMatchRequest: Encodable {
  let platform: String
  let appUserId: String?
  let deviceId: String?
  let vendorId: String?
  let idfa: String?
  let idfv: String?
  let advertiserTrackingEnabled: Bool
  let applicationTrackingEnabled: Bool
  let appVersion: String
  let sdkVersion: String
  let osVersion: String
  let deviceModel: String
  let deviceLocale: String
  let deviceLanguageCode: String
  let timezoneOffsetSeconds: Int
  let screenWidth: Int
  let screenHeight: Int
  let devicePixelRatio: Double
  let bundleId: String
  let clientTimestamp: String
  let metadata: [String: String]
}

struct MMPMatchResponse: Decodable {
  let matched: Bool
  let confidence: AttributionMatchInfo.Confidence?
  let matchScore: Double?
  let clickId: Int?
  let linkId: String?
  let network: String?
  let redirectUrl: String?
  // The backend types `queryParams` as a free-form object whose values are
  // strings *or arrays of strings* (a query key can appear more than once).
  // Modelling it as `[String: String]` would throw on the array case and fail
  // the whole decode, so we keep it loosely typed as JSON.
  let queryParams: [String: JSON]?
  let acquisitionAttributes: [String: JSON]?
  let matchedAt: String?
  let breakdown: [String: JSON]?

  private enum CodingKeys: String, CodingKey {
    case matched
    case confidence
    case matchScore
    case clickId
    case linkId
    case network
    case redirectUrl
    case queryParams
    case acquisitionAttributes
    case matchedAt
    case breakdown
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    matched = try container.decode(Bool.self, forKey: .matched)
    // The backend types `confidence` as a free-form string. Decode it
    // leniently so an unrecognised value (e.g. a future tier) degrades to
    // `nil` instead of failing the entire response decode.
    confidence = try? container.decodeIfPresent(AttributionMatchInfo.Confidence.self, forKey: .confidence)
    matchScore = try container.decodeIfPresent(Double.self, forKey: .matchScore)
    clickId = try container.decodeIfPresent(Int.self, forKey: .clickId)
    linkId = try container.decodeIfPresent(String.self, forKey: .linkId)
    network = try container.decodeIfPresent(String.self, forKey: .network)
    redirectUrl = try container.decodeIfPresent(String.self, forKey: .redirectUrl)
    queryParams = try container.decodeIfPresent([String: JSON].self, forKey: .queryParams)
    acquisitionAttributes = try container.decodeIfPresent([String: JSON].self, forKey: .acquisitionAttributes)
    matchedAt = try container.decodeIfPresent(String.self, forKey: .matchedAt)
    breakdown = try container.decodeIfPresent([String: JSON].self, forKey: .breakdown)
  }
}
