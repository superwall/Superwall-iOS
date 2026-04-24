//
//  AssetResource.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 24/04/2026.
//

import Foundation

/// A type that can be registered against ``SuperwallOptions/localResources`` and
/// served to the paywall webview via the `swlocal://` URL scheme.
///
/// `URL` conforms out of the box, so existing call sites registering file URLs
/// keep working. To register an asset from an `.xcassets` Data Set (the iOS
/// equivalent of Android's `R.raw.*` resource IDs), use ``CatalogAsset``.
///
/// ```swift
/// options.localResources = [
///   "hero-image": Bundle.main.url(forResource: "hero", withExtension: "png")!,
///   "hero-video": CatalogAsset(name: "HeroVideo")
/// ]
/// ```
public protocol AssetResource {}

extension URL: AssetResource {}

/// An entry in an asset catalog (`.xcassets`).
///
/// Resolved at load time by trying `NSDataAsset(name:bundle:)` first (Data Set,
/// raw bytes preserved with no re-encoding), then falling back to
/// `UIImage(named:in:compatibleWith:)` re-encoded as PNG (Image Set).
///
/// Prefer a Data Set if you can — it's lossless and works for any file type
/// (images, video, Lottie JSON, etc.). The Image Set fallback exists so an
/// existing `Logo` or icon Image Set "just works" without restructuring your
/// asset catalog, but be aware: it picks a single scale variant and encodes
/// to PNG, which can be larger than the original asset.
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
