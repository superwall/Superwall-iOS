//
//  File.swift
//  
//
//  Created by Yusuf Tör on 08/05/2024.
//

import Foundation

struct ManifestDataFetchable: Identifiable {
  var id: String {
    return item.id
  }
  let item: ArchivalManifestItem
  let isMainDocument: Bool
}

struct ManifestDataFetcher: TaskExecutor {
  private let urlSession = URLSession(configuration: .default)

  func perform(using input: ManifestDataFetchable) async throws -> ArchivalManifestItemDownloaded {
    return try await fetchDataForManifest(
      manifest: input.item,
      isMainDocument: input.isMainDocument
    )
  }

  func fetchDataForManifest(
    manifest: ArchivalManifestItem,
    isMainDocument: Bool
  ) async throws -> ArchivalManifestItemDownloaded {
    let request = URLRequest(url: manifest.url)
    let (data, _) = try await urlSession.data(for: request)

    return ArchivalManifestItemDownloaded(
      url: manifest.url,
      mimeType: manifest.mimeType,
      data: data,
      isMainDocument: isMainDocument
    )
  }
}
