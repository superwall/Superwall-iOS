//
//  String+RemoveChars.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

extension String {
//  var isNumber: Bool {
//    let numberSet = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
//    let input = trimmingCharacters(in: .whitespacesAndNewlines)
//    return !input.isEmpty && input.rangeOfCharacter(from: numberSet.inverted) == nil
//  }
//
  func removeCharacters(from forbiddenChars: CharacterSet) -> String {
    let passed = self.unicodeScalars.filter { !forbiddenChars.contains($0) }
    return String(String.UnicodeScalarView(passed))
  }
}
