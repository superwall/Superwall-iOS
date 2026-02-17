//
//  LocalFileSchemeHandlerTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/11/2025.
//
// swiftlint:disable all

import Testing
@testable import SuperwallKit
import Foundation

@Suite(.serialized)
struct LocalFileSchemeHandlerTests {

  // MARK: - Scheme Tests

  @Test("Scheme constant is correct")
  func schemeConstant() {
    #expect(LocalFileSchemeHandler.scheme == "swlocal")
  }

  // MARK: - Error Tests

  @Test("FileError invalidURL has description")
  func fileErrorInvalidURL() {
    let error = LocalFileSchemeHandler.FileError.invalidURL
    #expect(error.errorDescription == "Invalid local file URL format")
  }

  @Test("FileError fileNotFound includes path")
  func fileErrorFileNotFound() {
    let error = LocalFileSchemeHandler.FileError.fileNotFound("hero-video")
    #expect(error.errorDescription == "File not found: hero-video")
  }

  @Test("FileError unableToReadFile includes path")
  func fileErrorUnableToRead() {
    let error = LocalFileSchemeHandler.FileError.unableToReadFile("/tmp/missing.mp4")
    #expect(error.errorDescription == "Unable to read file: /tmp/missing.mp4")
  }

  // MARK: - loadFile Tests

  @Test("loadFile throws invalidURL when URL has no host")
  func loadFileNoHost() {
    let handler = LocalFileSchemeHandler()
    let url = URL(string: "swlocal://")!
    #expect(throws: LocalFileSchemeHandler.FileError.invalidURL) {
      try handler.loadFile(from: url)
    }
  }

  @Test("loadFile throws fileNotFound for unregistered localResourceId")
  func loadFileUnregisteredId() {
    let handler = LocalFileSchemeHandler()
    Superwall.shared.options.localResources = [:]
    let url = URL(string: "swlocal://hero-video")!
    #expect(throws: LocalFileSchemeHandler.FileError.fileNotFound("hero-video")) {
      try handler.loadFile(from: url)
    }
  }

  @Test("loadFile returns data and mime type for registered localResourceId")
  func loadFileRegisteredId() throws {
    let handler = LocalFileSchemeHandler()

    // Create a temp file
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("test-asset.mp4")
    let testData = Data("fake video content".utf8)
    try testData.write(to: tempFile)
    defer { try? FileManager.default.removeItem(at: tempFile) }

    Superwall.shared.options.localResources = ["hero-video": tempFile]
    let url = URL(string: "swlocal://hero-video")!

    let (data, mimeType) = try handler.loadFile(from: url)
    #expect(data == testData)
    #expect(mimeType == "video/mp4")

    // Clean up
    Superwall.shared.options.localResources = [:]
  }

  @Test("loadFile throws unableToReadFile when file URL points to missing file")
  func loadFileBadFileUrl() {
    let handler = LocalFileSchemeHandler()
    let badURL = URL(fileURLWithPath: "/nonexistent/path/file.png")
    Superwall.shared.options.localResources = ["hero-image": badURL]
    let url = URL(string: "swlocal://hero-image")!

    #expect(throws: LocalFileSchemeHandler.FileError.unableToReadFile("/nonexistent/path/file.png")) {
      try handler.loadFile(from: url)
    }

    // Clean up
    Superwall.shared.options.localResources = [:]
  }

  @Test("loadFile detects correct mime types from file extension")
  func loadFileMimeTypes() throws {
    let handler = LocalFileSchemeHandler()
    let tempDir = FileManager.default.temporaryDirectory
    let testData = Data("test".utf8)

    let cases: [(String, String, String)] = [
      ("test.png", "hero-png", "image/png"),
      ("test.jpg", "hero-jpg", "image/jpeg"),
      ("test.webp", "hero-webp", "image/webp"),
      ("test.heic", "hero-heic", "image/heic"),
      ("test.heif", "hero-heif", "image/heif"),
      ("test.avif", "hero-avif", "image/avif"),
      ("test.bmp", "hero-bmp", "image/bmp"),
      ("test.tiff", "hero-tiff", "image/tiff"),
      ("test.json", "hero-json", "application/json"),
      ("test.mov", "hero-mov", "video/quicktime"),
      ("test.hevc", "hero-hevc", "video/hevc"),
    ]

    for (filename, resourceId, expectedMime) in cases {
      let tempFile = tempDir.appendingPathComponent(filename)
      try testData.write(to: tempFile)
      defer { try? FileManager.default.removeItem(at: tempFile) }

      Superwall.shared.options.localResources = [resourceId: tempFile]
      let url = URL(string: "swlocal://\(resourceId)")!

      let (_, mimeType) = try handler.loadFile(from: url)
      #expect(mimeType == expectedMime, "Expected \(expectedMime) for \(filename), got \(mimeType)")
    }

    // Clean up
    Superwall.shared.options.localResources = [:]
  }
}
