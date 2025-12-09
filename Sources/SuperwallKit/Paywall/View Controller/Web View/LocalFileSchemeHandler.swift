//
//  LocalFileSchemeHandler.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/11/2025.
//

import Foundation
import WebKit

/// Handles custom URL scheme requests for serving local files to the paywall webview.
///
/// This enables paywalls to reference local files (videos, images, etc.) bundled with the app.
///
/// ## URL Format
/// ```
/// swlocal://path/to/file.mp4
/// ```
///
/// ## Usage in Paywall HTML
/// ```html
/// <video src="swlocal://design/intro-video.mp4" autoplay></video>
/// <img src="swlocal://images/hero.png">
/// ```
final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
  /// The custom URL scheme for local files
  static let scheme = "swlocal"

  /// Errors that can occur during file loading
  enum FileError: LocalizedError {
    case invalidURL
    case fileNotFound(String)
    case unableToReadFile(String)

    var errorDescription: String? {
      switch self {
      case .invalidURL:
        return "Invalid local file URL format"
      case .fileNotFound(let path):
        return "File not found: \(path)"
      case .unableToReadFile(let path):
        return "Unable to read file: \(path)"
      }
    }
  }

  // MARK: - WKURLSchemeHandler

  func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    guard let url = urlSchemeTask.request.url else {
      urlSchemeTask.didFailWithError(FileError.invalidURL)
      return
    }

    do {
      let (data, mimeType) = try loadFile(from: url)

      let response = URLResponse(
        url: url,
        mimeType: mimeType,
        expectedContentLength: data.count,
        textEncodingName: nil
      )

      urlSchemeTask.didReceive(response)
      urlSchemeTask.didReceive(data)
      urlSchemeTask.didFinish()
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Failed to load local file",
        info: ["url": url.absoluteString, "error": error.localizedDescription]
      )
      urlSchemeTask.didFailWithError(error)
    }
  }

  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    // No cleanup needed for synchronous file loading
  }

  // MARK: - File Loading

  /// Loads a file from the app bundle based on the URL path
  /// - Parameter url: The swlocal:// URL
  /// - Returns: Tuple of file data and MIME type
  private func loadFile(from url: URL) throws -> (Data, String) {
    // URL format: swlocal://path/to/file.ext
    // The host + path together form the file path
    guard let host = url.host else {
      throw FileError.invalidURL
    }

    // Combine host and path to get full file path
    // e.g., swlocal://design/video.mp4 -> design/video.mp4
    let filePath: String
    if url.path.isEmpty {
      filePath = host
    } else {
      filePath = host + url.path
    }

    guard let fileURL = findInBundle(path: filePath) else {
      throw FileError.fileNotFound(filePath)
    }

    guard let data = try? Data(contentsOf: fileURL) else {
      throw FileError.unableToReadFile(filePath)
    }

    let mimeType = self.mimeType(for: fileURL.pathExtension)

    return (data, mimeType)
  }

  /// Attempts to find a file in the bundle
  private func findInBundle(path: String) -> URL? {
    // Try with the path as-is in the resource path
    if let resourcePath = Bundle.main.resourcePath {
      let fullPath = (resourcePath as NSString).appendingPathComponent(path)
      if FileManager.default.fileExists(atPath: fullPath) {
        return URL(fileURLWithPath: fullPath)
      }
    }

    // Try using url(forResource:withExtension:)
    let nsPath = path as NSString
    let name = nsPath.deletingPathExtension
    let ext = nsPath.pathExtension

    if !ext.isEmpty, let url = Bundle.main.url(forResource: name, withExtension: ext) {
      return url
    }

    // Try with subdirectory
    let directory = (path as NSString).deletingLastPathComponent
    let filename = (path as NSString).lastPathComponent
    let fileNameWithoutExt = (filename as NSString).deletingPathExtension
    let fileExt = (filename as NSString).pathExtension

    if !directory.isEmpty,
       let url = Bundle.main.url(
        forResource: fileNameWithoutExt,
        withExtension: fileExt,
        subdirectory: directory
       ) {
      return url
    }

    return nil
  }

  // MARK: - MIME Type Detection

  /// Returns the MIME type for a file extension
  private func mimeType(for pathExtension: String) -> String {
    switch pathExtension.lowercased() {
    // Video
    case "mp4", "m4v":
      return "video/mp4"
    case "mov":
      return "video/quicktime"
    case "webm":
      return "video/webm"
    case "avi":
      return "video/x-msvideo"

    // Audio
    case "mp3":
      return "audio/mpeg"
    case "wav":
      return "audio/wav"
    case "m4a", "aac":
      return "audio/aac"
    case "ogg":
      return "audio/ogg"

    // Images
    case "jpg", "jpeg":
      return "image/jpeg"
    case "png":
      return "image/png"
    case "gif":
      return "image/gif"
    case "webp":
      return "image/webp"
    case "svg":
      return "image/svg+xml"

    // Other
    case "json":
      return "application/json"
    case "pdf":
      return "application/pdf"
    case "html", "htm":
      return "text/html"
    case "css":
      return "text/css"
    case "js":
      return "application/javascript"

    default:
      return "application/octet-stream"
    }
  }
}
