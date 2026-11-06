//
//  CustomProductPage.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 06/11/2026.
//

import Foundation

/// An App Store custom product page and the deep link set for it in App Store
/// Connect.
///
/// The backend reads these from the App Store Connect API, because the app is
/// only given the deep link, never the page's ID.
struct CustomProductPage: Codable, Equatable {
  /// The page's ID in App Store Connect, the `ppid` in its App Store URL.
  let id: String

  /// The page's name in App Store Connect.
  let name: String?

  /// The deep link the App Store opens the app with after an install from
  /// this page.
  let deepLink: String

  /// The page whose deep link is one of `urls`.
  ///
  /// The list can hold the same page more than once, once for each of its
  /// versions. Returns `nil` when no page matches, or when different pages
  /// share the deep link, because then there's no telling which one the user
  /// came from.
  static func matching(
    _ urls: [URL],
    in pages: [CustomProductPage]
  ) -> CustomProductPage? {
    let urlStrings = Set(urls.map(\.absoluteString))
    let matches = pages.filter { urlStrings.contains($0.deepLink) }

    guard let match = matches.first else {
      return nil
    }
    if matches.contains(where: { $0.id != match.id }) {
      return nil
    }
    return match
  }
}
