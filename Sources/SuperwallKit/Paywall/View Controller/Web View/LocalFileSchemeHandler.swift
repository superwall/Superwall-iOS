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
/// The URL host is used as a `localResourceId` key to look up the file URL
/// in `SuperwallOptions.localResources`.
///
/// ## URL Format
/// ```
/// swlocal://{localResourceId}
/// ```
///
/// ## Usage in Paywall HTML
/// ```html
/// <video src="swlocal://hero-video" autoplay></video>
/// <img src="swlocal://hero-image">
/// ```
final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
  /// The custom URL scheme for local files
  static let scheme = "swlocal"

  /// Errors that can occur during file loading
  enum FileError: LocalizedError, Equatable {
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

  /// Loads a file from `SuperwallOptions.localResources` based on the URL host (the localResourceId).
  /// - Parameter url: The swlocal:// URL where the host is the localResourceId
  /// - Returns: Tuple of file data and MIME type
  func loadFile(from url: URL) throws -> (Data, String) {
    guard let host = url.host else {
      throw FileError.invalidURL
    }

    guard let localURL = Superwall.shared.options.localResources[host] else {
      throw FileError.fileNotFound(host)
    }

    guard let data = try? Data(contentsOf: localURL) else {
      throw FileError.unableToReadFile(localURL.path)
    }

    let mimeType = self.mimeType(for: localURL.pathExtension)
    return (data, mimeType)
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
    case "hevc", "h265":
      return "video/hevc"

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
    case "heic":
      return "image/heic"
    case "heif":
      return "image/heif"
    case "avif":
      return "image/avif"
    case "bmp":
      return "image/bmp"
    case "tif", "tiff":
      return "image/tiff"

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
