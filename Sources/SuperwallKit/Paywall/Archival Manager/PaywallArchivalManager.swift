//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

final class PaywallArchivalManager {
  private let webArchiveManager: WebArchiveManager?

  init(
    baseDirectory: URL? = nil,
    webArchiveManager: WebArchiveManager? = nil
  ) {
    let directory: URL

    if let baseDirectory = baseDirectory {
      directory = baseDirectory
    } else {
      let cacheDirectory = try? FileManager.default.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      .appendingPathComponent("paywalls")

      guard let cacheDirectory = cacheDirectory else {
        self.webArchiveManager = nil
        return
      }

      directory = cacheDirectory
    }

    self.webArchiveManager = webArchiveManager ?? WebArchiveManager(baseURL: directory)
  }

  /// Attempts to preload the archive.
  func preloadArchive(paywall: Paywall) async {
    guard let manifest = paywall.manifest else {
      return
    }
    guard paywall.isUsingManifest else {
      return
    }
    guard let webArchiveManager = webArchiveManager else {
      return
    }
    _ = try? await webArchiveManager.getArchiveURL(forManifest: manifest)
  }

  /// Determines whether the loading of the paywall webview should wait for the web archive to finish loading.
  func shouldAlwaysUseWebArchive(manifest: ArchivalManifest?) -> Bool {
    if webArchiveManager == nil {
      return false
    }
    guard let manifest = manifest else {
      return false
    }
    if manifest.use == .always {
      return true
    }
    return false
  }

  /// Returns the URL of the cached archive, if available.
  func getCachedArchiveURL(manifest: ArchivalManifest?) -> URL? {
    guard let webArchiveManager = webArchiveManager else {
      return nil
    }
    guard let manifest = manifest else {
      return nil
    }
    if manifest.use == .never {
      return nil
    }
    return webArchiveManager.getArchiveURLFromCache(forManifest: manifest)
  }

  /// Returns the URL of the archive.
  func getArchiveURL(manifest: ArchivalManifest?) async -> URL? {
    guard let webArchiveManager = webArchiveManager else {
      return nil
    }
    guard let manifest = manifest else {
      return nil
    }
    if manifest.use == .never {
      return nil
    }
    return try? await webArchiveManager.getArchiveURL(forManifest: manifest)
  }
}
