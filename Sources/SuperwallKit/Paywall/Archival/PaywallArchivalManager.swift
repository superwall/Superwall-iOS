//
//  File.swift
//  
//
//  Created by Brian Anglin on 4/27/24.
//

import Foundation
class PaywallArchivalManager {
  
  private let webArchiveManager: WebArchiveManager?
  init(
    baseDirectory: URL? = nil,
    webArchiveManager: WebArchiveManager? = nil
  ) {
    let _baseDirectory = baseDirectory ?? (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent("paywalls"))
    
    guard let baseDirectory = _baseDirectory else {
      self.webArchiveManager = nil
      return
    }
    self.webArchiveManager = webArchiveManager ?? WebArchiveManager(baseURL: baseDirectory)
  }
  
  // Should
  func preloadArchiveAndShouldSkipViewControllerCache(paywall: Paywall) -> Bool {
    if let webArchiveManager = self.webArchiveManager {
      if let manifest = paywall.manifest {
        if manifest.use == .never {
          return false
        }
        Task(priority: .background) {
          await webArchiveManager.archiveForManifest(manifest:manifest)
        }
        return true
      }
    }
    return false
  }
  
  
  // If we should be really agressive and wait for the archival to finsih
  // before we load
  func shouldWaitForWebArchiveToLoad(paywall: Paywall) -> Bool {
    if let webArchiveManager = self.webArchiveManager {
      if let manifest = paywall.manifest {
        if manifest.use == .always {
          return true
        }
      }
    }
    return false
  }
  
  // We'll try to see if it's cached, if not we'll just
  // skip it and fall back to the normal method of loading
  func cachedArchiveForPaywallImmediately(paywall: Paywall) -> URL? {
    if let webArchiveManager = self.webArchiveManager {
      if let manifest = paywall.manifest {
        if manifest.use == .never {
          return nil
        }
        return webArchiveManager.archiveForManifestImmediately(manifest: manifest)
      }
    }
    return nil
  }
  
  func cachedArchiveForPaywall(paywall: Paywall) async -> URL? {
    if let webArchiveManager = self.webArchiveManager {
      if let manifest = paywall.manifest {
        if manifest.use == .never {
          return nil
        }
        let result = await webArchiveManager.archiveForManifest(manifest: manifest)
        switch result {
          case .success(let url):
            return url
        case .failure:
            return nil
        }
      }
    }
    return nil
  }
}
