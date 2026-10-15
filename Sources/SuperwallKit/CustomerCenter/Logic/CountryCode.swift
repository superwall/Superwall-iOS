//
//  CountryCode.swift
//
//
//  Created by Yusuf Tör on 23/09/2026.
//

import Foundation

/// Converts ISO 3166-1 country codes from three letters to two.
///
/// StoreKit reports the App Store country as three letters (`Storefront.countryCode`), while the
/// App Store lookup endpoint only accepts two. Foundation has no direct conversion, but a locale
/// identifier's region is canonicalized to two letters, so `und_GBR` reads back as `GB`. An
/// unknown code comes back unchanged, which the length check turns into `nil`.
enum CountryCode {
  static func alpha2(fromAlpha3 code: String) -> String? {
    if code.count != 3 {
      return nil
    }
    let locale = Locale(identifier: "und_\(code.uppercased())")
    let region: String?
    if #available(iOS 16, *) {
      region = locale.region?.identifier
    } else {
      region = locale.regionCode
    }
    guard let region, region.count == 2 else { return nil }
    return region
  }
}
