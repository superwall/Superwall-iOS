//
//  DataMigratorTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 21/02/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

struct CacheTests {
  let testDocumentDirectory: URL
  let testApplicationSupportDirectory: URL
  var fileManager: TestFileManager
  var dataMigrator: Cache

  init() throws {
    // Create unique temporary directories for testing.
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    testDocumentDirectory = tempDir.appendingPathComponent("Documents")
    testApplicationSupportDirectory = tempDir.appendingPathComponent("ApplicationSupport")
    try FileManager.default.createDirectory(
      at: testDocumentDirectory,
      withIntermediateDirectories: true,
      attributes: nil
    )
    try FileManager.default.createDirectory(
      at: testApplicationSupportDirectory,
      withIntermediateDirectories: true,
      attributes: nil
    )
    fileManager = TestFileManager(
      testDocumentDirectory: testDocumentDirectory,
      testApplicationSupportDirectory: testApplicationSupportDirectory
    )
    dataMigrator = Cache(
      fileManager: fileManager,
      ioQueue: DispatchQueue(label: "ioQueue")
    )
  }

  /// Test moving user-specific data.
  @Test func testUserSpecificDataMigration() async throws {
    // Create a user-specific folder in the document directory with a file.
    let userDocFolder = testDocumentDirectory.appendingPathComponent(Cache.userSpecificDocumentDirectoryPrefix)
    try fileManager.createDirectory(at: userDocFolder, withIntermediateDirectories: true, attributes: nil)
    let sourceFile = userDocFolder.appendingPathComponent("userFile.txt")
    let fileContent = "User specific content"
    try fileContent.write(to: sourceFile, atomically: true, encoding: .utf8)

    dataMigrator.moveDataFromDocumentsToApplicationSupport()
    // Allow the async migration to complete.
    try await Task.sleep(nanoseconds: 100_000_000)

    // Verify the file has been moved to the Application Support directory.
    let userSupportFolder = testApplicationSupportDirectory.appendingPathComponent(Cache.userSpecificDocumentDirectoryPrefix)
    let destFile = userSupportFolder.appendingPathComponent("userFile.txt")
    #expect(!fileManager.fileExists(atPath: sourceFile.path))
    #expect(fileManager.fileExists(atPath: destFile.path))
    let migratedContent = try String(contentsOf: destFile, encoding: .utf8)
    #expect(migratedContent == fileContent)

    // Verify the user-specific document folder is removed if empty.
    if let contents = try? fileManager.contentsOfDirectory(atPath: userDocFolder.path) {
      #expect(contents.isEmpty)
    }
  }

  /// Test moving app-specific data.
  @Test func testAppSpecificDataMigration() async throws {
    // Create an app-specific folder in the document directory with a file.
    let appDocFolder = testDocumentDirectory.appendingPathComponent(Cache.appSpecificDocumentDirectoryPrefix)
    try fileManager.createDirectory(at: appDocFolder, withIntermediateDirectories: true, attributes: nil)
    let sourceFile = appDocFolder.appendingPathComponent("appFile.txt")
    let fileContent = "App specific content"
    try fileContent.write(to: sourceFile, atomically: true, encoding: .utf8)

    dataMigrator.moveDataFromDocumentsToApplicationSupport()
    try await Task.sleep(nanoseconds: 100_000_000)

    // Verify the file has been moved.
    let appSupportFolder = testApplicationSupportDirectory.appendingPathComponent(Cache.appSpecificDocumentDirectoryPrefix)
    let destFile = appSupportFolder.appendingPathComponent("appFile.txt")
    #expect(!fileManager.fileExists(atPath: sourceFile.path))
    #expect(fileManager.fileExists(atPath: destFile.path))
    let migratedContent = try String(contentsOf: destFile, encoding: .utf8)
    #expect(migratedContent == fileContent)

    if let contents = try? fileManager.contentsOfDirectory(atPath: appDocFolder.path) {
      #expect(contents.isEmpty)
    }
  }

  /// Test that an existing file at the destination is overwritten.
  @Test func testOverwriteDestination() async throws {
    let userDocFolder = testDocumentDirectory.appendingPathComponent(Cache.userSpecificDocumentDirectoryPrefix)
    try fileManager.createDirectory(at: userDocFolder, withIntermediateDirectories: true, attributes: nil)
    let sourceFile = userDocFolder.appendingPathComponent("overwrite.txt")
    let sourceContent = "Source content"
    try sourceContent.write(to: sourceFile, atomically: true, encoding: .utf8)

    let userSupportFolder = testApplicationSupportDirectory.appendingPathComponent(Cache.userSpecificDocumentDirectoryPrefix)
    try fileManager.createDirectory(at: userSupportFolder, withIntermediateDirectories: true, attributes: nil)
    let destFile = userSupportFolder.appendingPathComponent("overwrite.txt")
    let destContent = "Old destination content"
    try destContent.write(to: destFile, atomically: true, encoding: .utf8)

    dataMigrator.moveDataFromDocumentsToApplicationSupport()
    try await Task.sleep(nanoseconds: 100_000_000)

    let finalContent = try String(contentsOf: destFile, encoding: .utf8)
    #expect(finalContent == sourceContent)
    #expect(!fileManager.fileExists(atPath: sourceFile.path))
  }

  /// Test that empty source folders are removed.
  @Test func testEmptyFoldersRemoval() async throws {
    let userDocFolder = testDocumentDirectory.appendingPathComponent(Cache.userSpecificDocumentDirectoryPrefix)
    try fileManager.createDirectory(at: userDocFolder, withIntermediateDirectories: true, attributes: nil)

    let appDocFolder = testDocumentDirectory.appendingPathComponent(Cache.appSpecificDocumentDirectoryPrefix)
    try fileManager.createDirectory(at: appDocFolder, withIntermediateDirectories: true, attributes: nil)

    dataMigrator.moveDataFromDocumentsToApplicationSupport()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(!fileManager.fileExists(atPath: userDocFolder.path))
    #expect(!fileManager.fileExists(atPath: appDocFolder.path))
  }
}
