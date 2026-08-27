//
//  ProductTitleFormatterTests.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Testing
@testable import SuperwallKit

@Suite("Product title formatting")
struct ProductTitleFormatterTests {
  @Test("tidies identifiers into something readable", arguments: [
    ("web_pro_monthly", "Web Pro Monthly"),
    ("pro-annual", "Pro Annual"),
    ("pro.monthly", "Pro Monthly"),
    ("proMonthly", "Pro Monthly"),
    ("pro", "Pro"),
    // Reverse-DNS is common and its leading component is never part of a readable name.
    ("com.acme.pro_monthly", "Acme Pro Monthly"),
    ("io.acme.lifetime", "Acme Lifetime"),
    // Two components only — nothing is dropped, since "com.pro" has no company segment to spare.
    ("com.pro", "Com Pro"),
    // Acronyms and years survive as written.
    ("SW_PRO_2024", "SW PRO 2024"),
    ("acme_PRO_yearly", "Acme PRO Yearly")
  ])
  func tidiesIdentifiers(identifier: String, expected: String) {
    #expect(ProductTitleFormatter.displayTitle(forIdentifier: identifier) == expected)
  }

  /// A title is cosmetic; it must never end up empty and leave a blank row.
  @Test("falls back to the identifier when there's nothing to tidy", arguments: ["", "...", "___"])
  func fallsBackToTheIdentifier(identifier: String) {
    #expect(ProductTitleFormatter.displayTitle(forIdentifier: identifier) == identifier)
  }
}
