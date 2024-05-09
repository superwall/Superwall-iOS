//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

struct WebArchive: Encodable {
  enum CodingKeys: String, CodingKey {
    case mainResource = "WebMainResource"
    case webSubresources = "WebSubresources"
  }
  let mainResource: WebArchiveMainResource
  let webSubresources: [WebArchiveResource]

  init(
    resource: WebArchiveResource,
    items: [ArchivalManifestItemDownloaded]
  ) {
    self.mainResource = WebArchiveMainResource(baseResource: resource)

    var webSubresources: [WebArchiveResource] = []
    for item in items {
      webSubresources.append(item.webArchiveResource)
    }
    self.webSubresources = webSubresources
  }
}

/// A web archive resource.
struct WebArchiveResource: Encodable {
  let url: URL
  let data: Data
  let mimeType: String

  enum CodingKeys: String, CodingKey {
    case url = "WebResourceURL"
    case data = "WebResourceData"
    case mimeType = "WebResourceMIMEType"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(url.absoluteString, forKey: .url)
    try container.encode(data, forKey: .data)
    try container.encode(mimeType, forKey: .mimeType)
  }
}

/// The main resource of the web archive.
struct WebArchiveMainResource: Encodable {
  let baseResource: WebArchiveResource

  enum CodingKeys: String, CodingKey {
    case url = "WebResourceURL"
    case data = "WebResourceData"
    case mimeType = "WebResourceMIMEType"
    case textEncodingName = "WebResourceTextEncodingName"
    case frameName = "WebResourceFrameName"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(baseResource.url.absoluteString, forKey: .url)
    try container.encode(baseResource.data, forKey: .data)
    try container.encode(baseResource.mimeType, forKey: .mimeType)
    try container.encode("UTF-8", forKey: .textEncodingName)
    try container.encode("", forKey: .frameName)
  }
}
