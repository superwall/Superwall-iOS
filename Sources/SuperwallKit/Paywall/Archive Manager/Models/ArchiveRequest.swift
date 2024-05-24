//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/05/2024.
//

import Foundation

/// The request to get the archive from the manifest.
struct ArchiveRequest: Identifiable {
  var id: String {
    return manifest.document.url.absoluteString
  }
  let manifest: ArchiveManifest
}
