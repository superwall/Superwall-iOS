//
//  File.swift
//
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

public struct ArchivingResult {
  public let plistData: Data?
  public let errors: [Error]
}


public class WebArchiveFileSytemManager {
  var encoder: PropertyListEncoder = {
    let plistEncoder = PropertyListEncoder()
    plistEncoder.outputFormat = .binary
    return plistEncoder
  }()
  
  private let archiveURL: URL
  init(archiveURL: URL) {
    self.archiveURL = archiveURL
  }
  
  func checkArchiveExists() -> Bool {
    return FileManager.default.fileExists(atPath: archiveURL.path)
  }
  
  func writeArchive(archive: WebArchive) -> Result<URL, Error> {
    guard let plistData = try? self.encoder.encode(archive) else {
      return .failure(ArchivingError.unknownError)
    }
    do {
      guard let directory = self.directoryURL(of: self.archiveURL) else {
        throw ArchivingError.unknownError
      }
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try plistData.write(to: self.archiveURL)
      return .success(self.archiveURL)
    } catch {
      return .failure(error)
    }
  }
  
  func directoryURL(of url: URL) -> URL? {
    var pathComponents = url.pathComponents
    guard !pathComponents.isEmpty else { return nil }
    
    // Remove the last component if it's a file, not a directory
    if pathComponents.last != "/", let _ = pathComponents.last?.split(separator: ".").last {
      pathComponents.removeLast()
    }
    
    let directoryURL = url.deletingLastPathComponent()
    return directoryURL
  }
}
