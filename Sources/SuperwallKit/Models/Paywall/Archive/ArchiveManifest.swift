//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

struct ArchiveManifest: Codable {
  let use: ArchiveManifestUsage
  let document: ArchiveManifestItem
  let resources: [ArchiveManifestItem]

  init(
    document: ArchiveManifestItem,
    resources: [ArchiveManifestItem],
    use: ArchiveManifestUsage
  ) {
    self.document = document
    self.resources = resources
    self.use = use
  }
}

struct ArchiveManifestItem: Codable, Identifiable {
  var id: String { url.absoluteString }
  let url: URL
  let mimeType: String

  init(url: URL, mimeType: String) {
    self.url = url
    self.mimeType = mimeType
  }
}
