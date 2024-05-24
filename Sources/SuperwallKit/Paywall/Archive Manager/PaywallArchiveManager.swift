//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

final class PaywallArchiveManager {
  private let webArchiveManager: WebArchiveManager?

  init() {
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
    self.webArchiveManager = WebArchiveManager(baseURL: cacheDirectory)
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
  func shouldAlwaysUseWebArchive(manifest: ArchiveManifest?) -> Bool {
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
  func getCachedArchiveURL(manifest: ArchiveManifest?) -> URL? {
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
  func getArchiveURL(forManifest manifest: ArchiveManifest?) async -> URL? {
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
