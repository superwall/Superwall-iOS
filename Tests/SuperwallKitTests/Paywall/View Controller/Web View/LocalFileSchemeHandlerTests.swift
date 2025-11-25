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
    let error = LocalFileSchemeHandler.FileError.fileNotFound("design/video.mp4")
    #expect(error.errorDescription == "File not found: design/video.mp4")
  }

  @Test("FileError unableToReadFile includes path")
  func fileErrorUnableToRead() {
    let error = LocalFileSchemeHandler.FileError.unableToReadFile("design/video.mp4")
    #expect(error.errorDescription == "Unable to read file: design/video.mp4")
  }
}
