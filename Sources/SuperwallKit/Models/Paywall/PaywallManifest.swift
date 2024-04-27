//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

// What we get back from the API

public enum ArchivalManifestUsage: Codable {
  case always
  case never
  case ifAvailableOnPaywallOpen
  
  enum CodingKeys: String, CodingKey {
    case always = "ALWAYS"
    case never = "NEVER"
    case ifAvailableOnPaywallOpen = "IF_AVAILABLE_ON_PAYWALL_OPEN"
  }
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let gatingType = CodingKeys(rawValue: rawValue) ?? .ifAvailableOnPaywallOpen
    switch gatingType {
    case .always:
      self = .always
    case .never:
      self = .never
    case .ifAvailableOnPaywallOpen:
      self = .ifAvailableOnPaywallOpen
    }
  }
}

public struct ArchivalManifest: Codable {
  public var use: ArchivalManifestUsage
  public var document: ArchivalManifestItem
  public var resources: [ArchivalManifestItem]
  public init(document: ArchivalManifestItem, resources: [ArchivalManifestItem], use: ArchivalManifestUsage) {
    self.document = document
    self.resources = resources
    self.use = use
  }
}

public struct ArchivalManifestItem: Codable, Identifiable {
  public var id: String {
    url.absoluteString
  }
  let url: URL
  let mimeType: String
  public init(url: URL, mimeType: String) {
    self.url = url
    self.mimeType = mimeType
  }
}

// What we return when the item is downloaded

struct ArchivalManifestDownloaded: Codable {
  let document: ArchivalManifestItemDownloaded
  let items: [ArchivalManifestItemDownloaded]
  func toWebArchive() -> WebArchive {
    var webArchive = WebArchive(resource: document.toWebArchiveResource())
    for item in items {
      webArchive.addSubresource(item.toWebArchiveResource())
    }
    return webArchive
  }
}


public struct ArchivalManifestItemDownloaded: Codable {
  let url: URL
  let mimeType: String
  let data: Data
  let isMainDocument: Bool
  func toWebArchiveResource() -> WebArchiveResource {
    return WebArchiveResource(url: url, data: data, mimeType: mimeType)
  }
}
