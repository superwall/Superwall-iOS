//
//  File.swift
//
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

/// Writes the web archive
final class WebArchiveFileSytemManager {
  var archiveExists: Bool {
    return FileManager.default.fileExists(atPath: archiveURL.path)
  }

  private var encoder: PropertyListEncoder = {
    let plistEncoder = PropertyListEncoder()
    plistEncoder.outputFormat = .binary
    return plistEncoder
  }()
  private let archiveURL: URL

  init(archiveURL: URL) {
    self.archiveURL = archiveURL
  }

  /// Writes a web archive to file.
  func write(archive: WebArchive) throws {
    guard let plistData = try? self.encoder.encode(archive) else {
      throw ArchivingError.unknown
    }
    guard let directory = archiveURL.directory else {
      throw ArchivingError.unknown
    }
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      try plistData.write(to: archiveURL)
    } catch {
      throw ArchivingError.unknown
    }
  }
}

private extension URL {
  /// Gets the directory of the URL.
  var directory: URL? {
    var pathComponents = pathComponents
    if pathComponents.isEmpty {
      return nil
    }

    // Remove the last component if it's a file, not a directory
    if pathComponents.last != "/",
      pathComponents.last?.split(separator: ".").last != nil {
      pathComponents.removeLast()
    }

    let directoryURL = deletingLastPathComponent()
    return directoryURL
  }
}
