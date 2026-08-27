//
//  ProductTitleFormatter.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Foundation

/// Turns a product identifier into something readable, for products that arrive without a name.
///
/// A stopgap, not a naming scheme. Web products come from `/v1/products`, which returns no display
/// name, so a Stripe subscription would otherwise show up on a customer's screen as
/// `web_pro_monthly`. Guessing at "Web Pro Monthly" is better than that, but it is still a guess —
/// the moment the payload carries a real name, that name wins and this stops being used.
enum ProductTitleFormatter {
  /// Reverse-DNS identifiers are common (`com.acme.pro.monthly`), and the leading component is
  /// never part of a name anyone wants to read.
  private static let reverseDomainPrefixes: Set<String> = ["com", "io", "co", "net", "org", "app"]

  static func displayTitle(forIdentifier identifier: String) -> String {
    var components = identifier
      .split { $0 == "." || $0 == "_" || $0 == "-" }
      .map(String.init)

    if components.count > 2,
      let first = components.first,
      reverseDomainPrefixes.contains(first.lowercased()) {
      components.removeFirst()
    }

    let words = components
      .flatMap(splitCamelCase)
      .map(capitalizeLeadingLetter)
      .filter { !$0.isEmpty }

    // Nothing usable came out — an identifier that's all separators, say. The raw value is a
    // poor title but it's at least the truth.
    return words.isEmpty ? identifier : words.joined(separator: " ")
  }

  /// `proMonthly` → `["pro", "Monthly"]`. Breaks before an uppercase letter that follows a
  /// lowercase one or a digit, which leaves acronyms like `SWPro` intact rather than shattering
  /// them into single letters.
  private static func splitCamelCase(_ word: String) -> [String] {
    var results: [String] = []
    var current = ""
    var previous: Character?

    for character in word {
      if character.isUppercase,
        let previous,
        previous.isLowercase || previous.isNumber,
        !current.isEmpty {
        results.append(current)
        current = ""
      }
      current.append(character)
      previous = character
    }
    if !current.isEmpty {
      results.append(current)
    }
    return results
  }

  /// Leaves a word that's already uppercase alone — `PRO` shouldn't become `Pro`, and a version
  /// or year like `2024` has no letter to raise.
  private static func capitalizeLeadingLetter(_ word: String) -> String {
    guard let first = word.first else { return word }
    if word.uppercased() == word {
      return word
    }
    return first.uppercased() + word.dropFirst()
  }
}
