//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

final class PaywallArchiveManager {
  private let webArchiveManager: WebArchiveManager?
  private let cacheDirectory: URL?
  private let bundledPaywalls: BundledPaywalls

  init(bundledPaywalls: BundledPaywalls = .shared) {
    self.bundledPaywalls = bundledPaywalls
    let cacheDirectory = try? FileManager.default.url(
      for: .cachesDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    .appendingPathComponent("paywalls")
    self.cacheDirectory = cacheDirectory

    guard let cacheDirectory = cacheDirectory else {
      self.webArchiveManager = nil
      return
    }
    self.webArchiveManager = WebArchiveManager(baseURL: cacheDirectory)
  }

  /// Attempts to preload the archive.
  func preloadArchive(paywall: Paywall) async {
    _ = await getBundledArchiveURL(for: paywall)
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

  /// Returns the URL of a web archive built from the paywall that `superwall bundle`
  /// placed in the app, if the app bundles this exact version of the paywall.
  ///
  /// The first call for a paywall reads its files and writes the archive, so it
  /// runs off the main actor.
  func getBundledArchiveURL(for paywall: Paywall) async -> URL? {
    let urls = [paywall.url] + paywall.urlConfig.endpoints.map(\.url)
    guard
      let cacheDirectory = cacheDirectory,
      let bundled = bundledPaywalls.paywall(matching: urls)
    else {
      return nil
    }
    let archiveURL = cacheDirectory
      .appendingPathComponent("bundled")
      .appendingPathComponent(URL(fileURLWithPath: bundled.document.file).lastPathComponent)
      .deletingPathExtension()
      .appendingPathExtension("webarchive")
    let fileSystemManager = WebArchiveFileSytemManager(archiveURL: archiveURL)
    if fileSystemManager.archiveExists {
      return archiveURL
    }
    do {
      try fileSystemManager.write(archive: bundledPaywalls.webArchive(for: bundled))
      return archiveURL
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .cache,
        message: "Could not read the bundled paywall \(bundled.identifier). Loading it from the network.",
        error: error
      )
      return nil
    }
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
