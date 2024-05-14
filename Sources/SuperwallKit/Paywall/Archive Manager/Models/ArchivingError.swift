//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/05/2024.
//

import Foundation

enum ArchivingError: Error {
  case unknown
  case mainDocumentUnavailable
  case emptyManifestItems
  case unsupportedUrl
  case requestFailed(resource: URL, error: Error)
  case invalidResponse(resource: URL)
  case unsupportedEncoding
  case invalidReferenceUrl(string: String)
}
