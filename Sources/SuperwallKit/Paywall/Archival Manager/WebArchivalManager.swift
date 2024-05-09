//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

/// Manages the retrieving and downloading of a paywall manifest.
final class WebArchiveManager {
  private var encoder: PropertyListEncoder = {
    let plistEncoder = PropertyListEncoder()
    plistEncoder.outputFormat = .binary
    return plistEncoder
  }()
  private let cachePolicy = URLRequest.CachePolicy.returnCacheDataElseLoad
  private let baseURL: URL
  private let manifestDataManager: TaskCoalescer<ManifestDataFetcher>
  private let archiveRequestManager: TaskCoalescer<ArchiveURLFetcher>
  private let archivalFileSystemManager: WebArchiveFileSytemManager

  init(
    baseURL: URL,
    manifestDataManager: TaskCoalescer<ManifestDataFetcher>? = nil,
    archiveRequestManager: TaskCoalescer<ArchiveURLFetcher>? = nil,
    archivalFileSystemManager: WebArchiveFileSytemManager? = nil
  ) {
    self.baseURL = baseURL
    self.archivalFileSystemManager = archivalFileSystemManager ?? WebArchiveFileSytemManager(archiveURL: baseURL)

    if let manifestDataManager = manifestDataManager {
      self.manifestDataManager = manifestDataManager
    } else {
      let manifestDataFetcher = ManifestDataFetcher()
      self.manifestDataManager = TaskCoalescer(executor: manifestDataFetcher)
    }

    if let archiveRequestManager = archiveRequestManager {
      self.archiveRequestManager = archiveRequestManager
    } else {
      let archiveURLFetcher = ArchiveURLFetcher()
      self.archiveRequestManager = TaskCoalescer(executor: archiveURLFetcher)
      archiveURLFetcher.archiveManager = self
    }
  }

  /// Gets the archive URL from the cache, if available.
  ///
  /// - Returns: An optional `URL` of the archive in the file system.
  func getArchiveURLFromCache(forManifest manifest: ArchivalManifest) -> URL? {
    let archiveURL = getFileSystemURL(forURL: manifest.document.url)
    let fsManager = WebArchiveFileSytemManager(archiveURL: archiveURL)
    if fsManager.archiveExists {
      return archiveURL
    }
    return nil
  }

  /// Gets the archive URL from the cache, if available. Otherwise, it downloads the manifest and
  /// writes it to disk before returning its URL.
  ///
  /// - Parameter manifest: The manifest to load.
  /// - Returns: An optional `URL` of the archive in the file system.
  func getArchiveURL(forManifest manifest: ArchivalManifest) async throws -> URL? {
    if let archiveURL = getArchiveURLFromCache(forManifest: manifest) {
      return archiveURL
    }

    let request = ArchivalRequest(manifest: manifest)
    return try? await archiveRequestManager.get(using: request)
  }

  /// Asynchronously downloads and writes the manifest to file.
  ///
  /// - Parameter manifest: The manifest to load.
  /// - Returns: A file system `URL` where the downloaded manifest is stored.
  func getArchiveURLForManifest(manifest: ArchivalManifest) async throws -> URL {
    let downloadedManifest = try await downloadManifest(manifest)
    let targetURL = getFileSystemURL(forURL: manifest.document.url)
    try await writeManifest(downloadedManifest, to: targetURL)
    return targetURL
  }

  /// Generates a webarchive file system URL for a given URL.
  ///
  /// - Parameter url: The `URL` of a manifest document.
  /// - Returns: A file system `URL` to store the downloaded manifest.
  private func getFileSystemURL(forURL url: URL) -> URL {
    let hostDashed = url.host?
      .split(separator: ".")
      .joined(separator: "-") ?? "unknown"
    var path = baseURL.appendingPathComponent(hostDashed.replacingOccurrences(of: "/", with: ""))
    for item in url.pathComponents.filter({ $0 != "/" }) {
      path = path.appendingPathComponent(item)
    }
    path = path
      .appendingPathComponent("cached")
      .appendingPathExtension("webarchive")

    return path
  }

  /// Downloads the main document and resources of the manifest file and compiles it into an `ArchivalManifestDownloaded`.
  private func downloadManifest(_ manifest: ArchivalManifest) async throws -> ArchivalManifestDownloaded {
    let results = await withThrowingTaskGroup(
      of: ArchivalManifestItemDownloaded.self,
      returning: [ArchivalManifestItemDownloaded].self
    ) { [weak self] group in
      guard let self = self else {
        return []
      }
      var results: [ArchivalManifestItemDownloaded] = []

      group.addTask {
        let fetchableData = ManifestDataFetchable(
          item: manifest.document,
          isMainDocument: true
        )
        return try await self.manifestDataManager.get(using: fetchableData)
      }
      for item in manifest.resources {
        group.addTask {
          let fetchableData = ManifestDataFetchable(
            item: item,
            isMainDocument: false
          )
          return try await self.manifestDataManager.get(using: fetchableData)
        }
      }

      do {
        for try await result in group {
          results.append(result)
        }
        return results
      } catch {
        return []
      }
    }

    if results.isEmpty {
      throw ArchivingError.emptyManifestItems
    }
    guard let mainDocument = results.first(where: { $0.isMainDocument }) else {
      throw ArchivingError.mainDocumentUnavailable
    }
    let restOfItems = results.filter { !$0.isMainDocument }
    return ArchivalManifestDownloaded(
      document: mainDocument,
      items: restOfItems
    )
  }

  /// Writes the manifest to disk.
  private func writeManifest(_ manifest: ArchivalManifestDownloaded, to url: URL) async throws {
    let fsManager = WebArchiveFileSytemManager(archiveURL: url)
    try fsManager.write(archive: manifest.webArchive)
  }
}
