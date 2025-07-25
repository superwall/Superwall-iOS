//
//  AppStoreProduct.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/07/2025.
//

import Foundation

/// An Apple App Store product.
@objc(SWKAppStoreProduct)
@objcMembers
public final class AppStoreProduct: NSObject, Codable, Sendable {
  /// The product identifier.
  public let id: String

  enum CodingKeys: String, CodingKey {
    case id = "productIdentifier"
    case store
  }

  init(
    id: String
  ) {
    self.id = id
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    let rawStore = try container.decode(String.self, forKey: .store)
    if rawStore != "APP_STORE" {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Not an App Store product \(rawStore)"
        )
      )
    }
    super.init()
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? AppStoreProduct else {
      return false
    }
    return id == other.id
  }

  public override var hash: Int {
    var hasher = Hasher()
    hasher.combine(id)
    return hasher.finalize()
  }
}
