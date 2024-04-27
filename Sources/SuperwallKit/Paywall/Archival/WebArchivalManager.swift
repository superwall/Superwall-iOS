//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation

public enum ArchivingError: LocalizedError {
  case unknownError
  case unsupportedUrl
  case requestFailed(resource: URL, error: Error)
  case invalidResponse(resource: URL)
  case unsupportedEncoding
  case invalidReferenceUrl(string: String)
  
  public var errorDescription: String? {
    switch self {
    case .unknownError: return "Uknown error"
    case .unsupportedUrl: return "Unsupported URL"
    case .requestFailed(let res, _): return "Failed to load " + res.absoluteString
    case .invalidResponse(let res): return "Invalid response for " + res.absoluteString
    case .unsupportedEncoding: return "Unsupported encoding"
    case .invalidReferenceUrl(let string): return "Invalid reference URL: " + string
    }
  }
}

public struct ArchivalRequest: Identifiable {
  public var id: String {
    return manifest.document.url.absoluteString
  }
  let manifest: ArchivalManifest
}

public class WebArchiveManager {
  private var encoder: PropertyListEncoder = {
    let plistEncoder = PropertyListEncoder()
    plistEncoder.outputFormat = .binary
    return plistEncoder
  }()
  private let cachePolicy = URLRequest.CachePolicy.returnCacheDataElseLoad
  private let urlSession: URLSession
  private let baseURL: URL
  private let requestCoalescence: RequestCoalescence<ArchivalManifestItem, Result<ArchivalManifestItemDownloaded, Error>>
  private let archivalCoalescence: RequestCoalescence<ArchivalRequest, Result<URL, ArchivingError>>
  private let archivalFileSystemManager: WebArchiveFileSytemManager
  public init(
    baseURL: URL,
    requestCoalescence: RequestCoalescence<ArchivalManifestItem, Result<ArchivalManifestItemDownloaded, Error>> = RequestCoalescence(),
    archivalCoalescence: RequestCoalescence<ArchivalRequest, Result<URL, ArchivingError>> = RequestCoalescence(),
    archivalFileSystemManager: WebArchiveFileSytemManager? = nil
  ) {
    self.baseURL = baseURL
    self.requestCoalescence = requestCoalescence
    self.archivalCoalescence = archivalCoalescence
    self.urlSession = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
    self.archivalFileSystemManager = archivalFileSystemManager ?? WebArchiveFileSytemManager(archiveURL: self.baseURL)
  }
  
  public func archiveForManifestImmediately(manifest: ArchivalManifest) -> URL? {
    let archivePath = self.fsPath(forURL: manifest.document.url)
    let fsManager = WebArchiveFileSytemManager(archiveURL: archivePath)
    if (fsManager.checkArchiveExists()) {
      return archivePath
    }
    return nil
  }
  
  public func archiveForManifest(manifest: ArchivalManifest) async -> Result<URL, ArchivingError> {
    //    let webArchiveFile
    let archivePath = self.fsPath(forURL: manifest.document.url)
    let fsManager = WebArchiveFileSytemManager(archiveURL: archivePath)
    if (fsManager.checkArchiveExists()) {
      return .success(archivePath)
    }
    let archivalRequest = ArchivalRequest(manifest: manifest)
    return await self.archivalCoalescence.get(input: archivalRequest) { request in
      return await self._archiveForManifest(manifest: request.manifest)
    }
  }
  
  private func _archiveForManifest(manifest: ArchivalManifest) async -> Result<URL, ArchivingError> {
    do {
      let downloadedManifest = try await self.downloadManifest(manifest: manifest)
      let targetPath = self.fsPath(forURL: manifest.document.url)
      try await self.writeManifest(manifest: downloadedManifest, path: targetPath)
      return .success(targetPath)
    } catch {
      return .failure(.unknownError)
    }
  }
  
  // Consistent way to look up the appropriate directory
  // for a given url
  private func fsPath(forURL: URL) -> URL {
    let hostDashed = forURL.host?.split(separator: ".").joined(separator: "-") ?? "unknown"
    var path = baseURL.appendingPathComponent(hostDashed.replacingOccurrences(of: "/", with: ""))
    for item in forURL.pathComponents.filter({ str in
      return str != "/"
    }) {
      path = path.appendingPathComponent(item)
    }
    path = path.appendingPathComponent("cached").appendingPathExtension("webarchive")
    
    return path
  }
  
  
  private func downloadManifest(manifest: ArchivalManifest) async throws -> ArchivalManifestDownloaded {
    let results = await withTaskGroup(of: Result<ArchivalManifestItemDownloaded, Error>.self, returning: [Result<ArchivalManifestItemDownloaded, Error>].self) {
      group in
      var results: [Result<ArchivalManifestItemDownloaded, Error>] = [];
      
      group.addTask {
        return await self.requestCoalescence.get(input: manifest.document) { (item) in
          let result = await self.fetchDataForManifest(manifest: item, isMainDocument: true)
          return result
        }
      }
      for item in manifest.resources {
        group.addTask {
          return await self.requestCoalescence.get(input: item) { item in
            return await self.fetchDataForManifest(manifest: item, isMainDocument: false)
          }
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
    let successfulResults = try results
      .filter({ item in
        if case .success = item {
          return true
        }
        return false
      }).map { item in
        return try item.get()
      }
    if (successfulResults.isEmpty) {
      throw NSError(domain: "com.example.error", code: 0, userInfo: [NSLocalizedDescriptionKey: "No results found"])
    }
    let document = successfulResults
      .first { item in
        return item.isMainDocument
      }
    
    guard let document = document else {
      throw NSError(domain: "com.example.error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Couldn't load document"])
    }
    let restOfItems = successfulResults.filter {
      item in return !item.isMainDocument
    }
    return ArchivalManifestDownloaded(document: document, items: restOfItems)
  }
  
  // Helper to write manifest
  private func writeManifest(manifest: ArchivalManifestDownloaded, path: URL) async throws -> Void {
    // Write it to disk
    //    WebArchiver(archiveURL: <#T##URL#>)
    let fsManager = WebArchiveFileSytemManager(archiveURL: self.fsPath(forURL: manifest.document.url))
    let result = fsManager.writeArchive(archive: manifest.toWebArchive())
    switch result {
    case .failure(let error):
      throw error
    case .success:
      return
    }
  }
  
  
  // Helper to actually fetch the manifes
  
  private func fetchDataForManifest(manifest: ArchivalManifestItem, isMainDocument: Bool) async -> Result<ArchivalManifestItemDownloaded, Error> {
    let request = URLRequest(url: manifest.url)
    do {
      let (data, _) = try await self.urlSession.data(for: request)
      return .success(ArchivalManifestItemDownloaded(url: manifest.url, mimeType: manifest.mimeType, data: data, isMainDocument: isMainDocument))
    } catch {
      print("Error", error )
      return .failure(error)
    }
  }
}
