//
//  CustomerCenterStringsTests.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("CustomerCenterStrings")
struct CustomerCenterStringsTests {
  init() {
    if !Superwall.isInitialized {
      Superwall.configure(apiKey: "test")
    }
  }

  @Test("english dictionary covers every key in en.lproj")
  func englishCoversBundle() throws {
    let bundle = LocalizationLogic.localizedBundle(Locale(identifier: "en"))
    let path = try #require(bundle.path(forResource: "Localizable", ofType: "strings"))
    let dict = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
    let ccKeys = dict.keys.filter { $0.hasPrefix("customer_center_") }
    #expect(!ccKeys.isEmpty)
    for key in ccKeys {
      #expect(englishStrings[key] == dict[key], "mismatch for \(key)")
    }
  }

  @Test("bundled lookup formats arguments and falls back to english then key")
  func bundledLookup() {
    let strings = CustomerCenterStrings.bundled(locale: Locale(identifier: "en"))
    #expect(strings.string("customer_center_renews_on", "Jan 1") == "Renews on Jan 1")
    #expect(strings.string("customer_center_not_a_key") == "customer_center_not_a_key")
  }

  @Test("every lproj contains every customer_center key")
  func allLocalesComplete() throws {
    let enBundle = LocalizationLogic.localizedBundle(Locale(identifier: "en"))
    let enPath = try #require(enBundle.path(forResource: "Localizable", ofType: "strings"))
    let enKeys = Set((NSDictionary(contentsOfFile: enPath) as? [String: String] ?? [:]).keys.filter { $0.hasPrefix("customer_center_") })
    for localization in Bundle.module.localizations where localization != "Base" {
      guard
        let path = Bundle.module.path(forResource: localization, ofType: "lproj").flatMap(Bundle.init(path:))?.path(forResource: "Localizable", ofType: "strings"),
        let dict = NSDictionary(contentsOfFile: path) as? [String: String]
      else { continue }
      #expect(enKeys.isSubset(of: Set(dict.keys)), "\(localization) is missing Customer Center keys")
    }
  }
}
