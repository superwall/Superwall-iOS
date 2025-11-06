//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  String+ROT13.swift
//
//  Created by Juanpe Catalán on 9/7/21.
//

import Foundation

extension String {
  func rot13() -> String {
    ROT13.string(self)
  }
}

private enum ROT13 {
  private static let key: [Character: Character] = {
    let size = Self.lowercase.count
    let halfSize: Int = size / 2

    var result: [Character: Character] = .init(minimumCapacity: size)

    for number in 0 ..< size {
      let index = (number + halfSize) % size

      result[Self.uppercase[number]] = Self.uppercase[index]
      result[Self.lowercase[number]] = Self.lowercase[index]
    }

    return result
  }()
  private static let lowercase: [Character] = Array("abcdefghijklmnopqrstuvwxyz")
  // swiftlint:disable:next force_unwrapping
  private static let uppercase: [Character] = Self.lowercase.map { $0.uppercased().first! }

  static func string(_ string: String) -> String {
    let transformed = string.map { Self.key[$0] ?? $0 }
    return String(transformed)
  }
}
