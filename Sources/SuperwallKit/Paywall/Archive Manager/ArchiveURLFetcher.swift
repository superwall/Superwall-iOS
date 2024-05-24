//
//  File.swift
//  
//
//  Created by Yusuf Tör on 08/05/2024.
//

import Foundation

final class ArchiveURLFetcher: TaskExecutor {
  weak var archiveManager: WebArchiveManager?

  func perform(using input: ArchiveRequest) async throws -> URL {
    guard let archiveManager = archiveManager else {
      throw CancellationError()
    }
    return try await archiveManager.getArchiveURLForManifest(input.manifest)
  }
}
