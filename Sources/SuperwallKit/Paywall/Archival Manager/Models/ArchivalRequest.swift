//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/05/2024.
//

import Foundation

/// The request to get the archival from the manifest.
struct ArchivalRequest: Identifiable {
  var id: String {
    return manifest.document.url.absoluteString
  }
  let manifest: ArchivalManifest
}
