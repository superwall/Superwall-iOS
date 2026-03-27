//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/11/2024.
//

import Foundation

struct AdServicesResponse: Decodable {
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
  let queryParams: [String: String]?
  let acquisitionAttributes: [String: JSON]?
  let matchedAt: String?
  let breakdown: [String: JSON]?
}
