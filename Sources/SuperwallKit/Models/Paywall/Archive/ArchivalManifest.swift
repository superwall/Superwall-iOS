//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

struct ArchivalManifest: Codable {
  let use: ArchivalManifestUsage
  let document: ArchivalManifestItem
  let resources: [ArchivalManifestItem]

  init(
    document: ArchivalManifestItem,
    resources: [ArchivalManifestItem],
    use: ArchivalManifestUsage
  ) {
    self.document = document
    self.resources = resources
    self.use = use
  }
}

struct ArchivalManifestItem: Codable, Identifiable {
  var id: String { url.absoluteString }
  let url: URL
  let mimeType: String

  init(url: URL, mimeType: String) {
    self.url = url
    self.mimeType = mimeType
  }
}
