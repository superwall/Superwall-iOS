//
//  File.swift
//  
//
//  Created by Yusuf Tör on 08/05/2024.
//

import Foundation

final class ArchiveURLFetcher: TaskExecutor {
  weak var archiveManager: WebArchiveManager?

  func perform(using input: ArchivalRequest) async throws -> URL {
    guard let archiveManager = archiveManager else {
      throw CancellationError()
    }
    return try await archiveManager.getArchiveURLForManifest(manifest: input.manifest)
  }
}
