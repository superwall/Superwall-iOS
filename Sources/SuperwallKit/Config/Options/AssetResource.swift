//
//  AssetResource.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 24/04/2026.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A type that can be registered against ``SuperwallOptions/localResources`` and
/// served to the paywall webview via the `swlocal://` URL scheme.
///
/// Conforming types:
/// - `URL` — a file on disk.
/// - `UIImage` — re-encoded as PNG when served to the webview.
/// - ``CatalogAsset`` — a deferred lookup against an `.xcassets` entry. Handles
///   both Image Sets and Data Sets (video, Lottie JSON, etc.).
///
/// ```swift
/// options.localResources = [
///   "hero-image": Bundle.main.url(forResource: "hero", withExtension: "png")!,
///   "logo":       UIImage(named: "Logo")!,
///   "hero-video": CatalogAsset(name: "HeroVideo")
/// ]
/// ```
public protocol AssetResource {}

extension URL: AssetResource {}

#if canImport(UIKit)
extension UIImage: AssetResource {}
#endif

/// An entry in an asset catalog (`.xcassets`).
///
/// Resolved at load time by trying `UIImage(named:in:compatibleWith:)` first
/// (Image Set, re-encoded as PNG), then falling back to
/// `NSDataAsset(name:bundle:)` (Data Set, raw bytes preserved with no
/// re-encoding).
///
/// Use a Data Set for non-image content (video, Lottie JSON, etc.) or when
/// you need lossless bytes. Image Sets work as-is for typical paywall imagery
/// like logos and icons.
public struct CatalogAsset: AssetResource {
  /// The name of the data asset as it appears in the asset catalog.
  public let name: String

  /// The bundle that contains the asset catalog.
  public let bundle: Bundle

  /// Creates a reference to a Data Set entry in an asset catalog.
  ///
  /// - Parameters:
  ///   - name: The name of the data asset as it appears in the asset catalog.
  ///   - bundle: The bundle that contains the asset catalog. Defaults to `.main`.
  public init(name: String, bundle: Bundle = .main) {
    self.name = name
    self.bundle = bundle
  }
}
