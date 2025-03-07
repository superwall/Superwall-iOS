//
//  TestFileManager.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 21/02/2025.
//
// swiftlint:disable all

import Foundation

/// Custom FileManager for testing that overrides the directory URLs.
class TestFileManager: FileManager {
  let testDocumentDirectory: URL
  let testApplicationSupportDirectory: URL

  init(testDocumentDirectory: URL, testApplicationSupportDirectory: URL) {
    self.testDocumentDirectory = testDocumentDirectory
    self.testApplicationSupportDirectory = testApplicationSupportDirectory
    super.init()
  }

  override func urls(
    for directory: FileManager.SearchPathDirectory,
    in domainMask: FileManager.SearchPathDomainMask
  ) -> [URL] {
    switch directory {
    case .documentDirectory:
      return [testDocumentDirectory]
    case .applicationSupportDirectory:
      return [testApplicationSupportDirectory]
    default:
      return super.urls(for: directory, in: domainMask)
    }
  }
}
