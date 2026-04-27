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
/// - `UIImage` — re-encoded as PNG when served to the webview. Use this to
///   register an asset catalog Image Set: `UIImage(named: "Logo")!`.
///
/// ```swift
/// options.localResources = [
///   "hero-image": Bundle.main.url(forResource: "hero", withExtension: "png")!,
///   "logo":       UIImage(named: "Logo")!
/// ]
/// ```
public protocol AssetResource {}

extension URL: AssetResource {}

#if canImport(UIKit)
extension UIImage: AssetResource {}
#endif
