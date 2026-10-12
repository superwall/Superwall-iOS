//
//  BundledPaywalls.swift
//
//
//  Created by Christo Todorov on 12/10/2026.
//

import Foundation

/// The `bundle.json` index that `superwall bundle` writes.
struct BundledPaywallsManifest: Decodable {
  struct File: Decodable {
    let url: URL
    let file: String
    let mimeType: String
  }

  struct Paywall: Decodable {
    let identifier: String
    let urls: [URL]
    let document: File
    let resources: [File]
  }

  let version: Int
  let paywalls: [Paywall]
}

/// The static config and paywalls that `superwall bundle` placed in the app's
/// `Superwall.bundle`.
final class BundledPaywalls {
  static let shared = BundledPaywalls(
    directory: Bundle.main.url(forResource: "Superwall", withExtension: "bundle")
  )
  static let supportedVersion = 1

  let config: Config?
  private let directory: URL?
  private let manifest: BundledPaywallsManifest?

  init(directory: URL?) {
    self.directory = directory
    guard let directory = directory else {
      manifest = nil
      config = nil
      return
    }
    manifest = Self.decodeManifest(in: directory)
    config = manifest == nil ? nil : Self.decodeConfig(in: directory)
  }

  func paywall(matching urls: [URL]) -> BundledPaywallsManifest.Paywall? {
    return manifest?.paywalls.first { bundled in
      bundled.urls.contains { urls.contains($0) }
    }
  }

  func webArchive(for paywall: BundledPaywallsManifest.Paywall) throws -> WebArchive {
    guard let directory = directory else {
      throw ArchivingError.mainDocumentUnavailable
    }
    let document = try Self.item(paywall.document, in: directory, isMainDocument: true)
    let resources = try paywall.resources.map {
      try Self.item($0, in: directory, isMainDocument: false)
    }
    return ArchiveManifestDownloaded(document: document, items: resources).webArchive
  }

  private static func item(
    _ file: BundledPaywallsManifest.File,
    in directory: URL,
    isMainDocument: Bool
  ) throws -> ArchiveManifestItemDownloaded {
    let data = try Data(contentsOf: directory.appendingPathComponent(file.file))
    return ArchiveManifestItemDownloaded(
      url: file.url,
      mimeType: file.mimeType,
      data: data,
      isMainDocument: isMainDocument
    )
  }

  private static func decodeManifest(in directory: URL) -> BundledPaywallsManifest? {
    do {
      let data = try Data(contentsOf: directory.appendingPathComponent("bundle.json"))
      let manifest = try JSONDecoder().decode(BundledPaywallsManifest.self, from: data)
      guard manifest.version <= supportedVersion else {
        Logger.debug(
          logLevel: .warn,
          scope: .cache,
          message: "Superwall.bundle was written by a newer CLI than this SDK reads. Update the SDK "
            + "or rebuild the bundle with a matching CLI. Ignoring the bundle.",
          info: ["version": manifest.version]
        )
        return nil
      }
      return manifest
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .cache,
        message: "Superwall.bundle has no readable bundle.json. Ignoring the bundle.",
        error: error
      )
      return nil
    }
  }

  private static func decodeConfig(in directory: URL) -> Config? {
    do {
      let data = try Data(contentsOf: directory.appendingPathComponent("static_config.json"))
      return try JSONDecoder.fromSnakeCase.decode(Config.self, from: data)
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .cache,
        message: "Superwall.bundle has no readable static_config.json. Bundled paywalls are only "
          + "used once config has been fetched.",
        error: error
      )
      return nil
    }
  }
}
