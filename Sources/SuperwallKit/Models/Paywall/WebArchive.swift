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
  var webSubresources: [WebArchiveResource]
  
  init(resource: WebArchiveResource) {
    self.mainResource = WebArchiveMainResource(baseResource: resource)
    self.webSubresources = []
  }
  
  mutating func addSubresource(_ subresource: WebArchiveResource) {
    self.webSubresources.append(subresource)
  }
}
struct WebArchiveResource: Encodable {
  
  enum CodingKeys: String, CodingKey {
    case url = "WebResourceURL"
    case data = "WebResourceData"
    case mimeType = "WebResourceMIMEType"
  }
  
  let url: URL
  let data: Data
  let mimeType: String
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(url.absoluteString, forKey: .url)
    try container.encode(data, forKey: .data)
    try container.encode(mimeType, forKey: .mimeType)
  }
}
struct WebArchiveMainResource: Encodable {
  
  enum CodingKeys: String, CodingKey {
    case url = "WebResourceURL"
    case data = "WebResourceData"
    case mimeType = "WebResourceMIMEType"
    case textEncodingName = "WebResourceTextEncodingName"
    case frameName = "WebResourceFrameName"
  }
  
  let baseResource: WebArchiveResource
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(baseResource.url.absoluteString, forKey: .url)
    try container.encode(baseResource.data, forKey: .data)
    try container.encode(baseResource.mimeType, forKey: .mimeType)
    try container.encode("UTF-8", forKey: .textEncodingName)
    try container.encode("", forKey: .frameName)
  }
}
