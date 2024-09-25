//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/09/2024.
//

import Foundation

/// An object that holds the AdServices attribution variables.
@objc(SWKAdServicesAttributes)
@objcMembers
public final class AdServicesAttributes: NSObject, Codable {
  /// The attribution value. A value of true returns if a user clicks an Apple Search Ads
  /// impression up to 30 days before your app download. If the API can’t find a
  /// matching attribution record, the attribution value is false.
  public let attribution: Bool

  /// The identifier of the organization that owns the campaign.
  ///
  /// Your orgId is the same as your account in the Apple Search Ads UI.
  public let orgId: Int

  /// The unique identifier for the campaign.
  public let campaignId: Int

  /// The identifier representing the assignment relationship between an ad object and an ad group. This applies to devices running iOS 15.2 and later.
  public let adGroupId: Int?

  /// The country or region for the campaign.
  public let countryOrRegion: String

  /// The identifier for the keyword.
  ///
  /// Note, when you enable search match, the API doesn’t return keywordId in the attribution response.
  public let keywordId: Int?

  /// The identifier representing the assignment relationship between an ad object and an ad group.
  ///
  /// This applies to devices running iOS 15.2 and later.
  public let adId: Int?

  /// Added by SDK
  public internal(set) var token = ""

  /// An enum whose cases represent the type of ad conversion.
  @objc(SWKConversionType)
  public enum ConversionType: Int, CustomStringConvertible, Codable {
    /// If the user downloaded the app for the first time.
    case download

    /// If the user redownloaded the app.
    case redownload

    public var description: String {
      switch self {
      case .download:
        return "Download"
      case .redownload:
        return "Redownload"
      }
    }

    // Custom decoding to handle strings
    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      let stringValue = try container.decode(String.self)

      switch stringValue {
      case ConversionType.download.description:
        self = .download
      case ConversionType.redownload.description:
        self = .redownload
      default:
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Invalid conversion type"
        )
      }
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(self.description)
    }
  }

  /// The type of conversion is either `Download` or `Redownload`.
  public let conversionType: ConversionType

  /// Can't get this without permission.
  // let clickDate: Date

  // Coding keys for encoding and decoding
  private enum CodingKeys: String, CodingKey {
    case attribution
    case orgId
    case campaignId
    case adGroupId
    case countryOrRegion
    case keywordId
    case adId
    case conversionType
    case token
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(attribution, forKey: .attribution)
    try container.encode(orgId, forKey: .orgId)
    try container.encode(campaignId, forKey: .campaignId)
    try container.encodeIfPresent(adGroupId, forKey: .adGroupId)
    try container.encode(countryOrRegion, forKey: .countryOrRegion)
    try container.encodeIfPresent(keywordId, forKey: .keywordId)
    try container.encodeIfPresent(adId, forKey: .adId)
    try container.encode(conversionType.description, forKey: .conversionType)
    try container.encode(token, forKey: .token)
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.attribution = try container.decode(Bool.self, forKey: .attribution)
    self.orgId = try container.decode(Int.self, forKey: .orgId)
    self.campaignId = try container.decode(Int.self, forKey: .campaignId)
    self.adGroupId = try container.decodeIfPresent(Int.self, forKey: .adGroupId)
    self.countryOrRegion = try container.decode(String.self, forKey: .countryOrRegion)
    self.keywordId = try container.decodeIfPresent(Int.self, forKey: .keywordId)
    self.adId = try container.decodeIfPresent(Int.self, forKey: .adId)
    self.conversionType = try container.decode(ConversionType.self, forKey: .conversionType)
    self.token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
  }
}
