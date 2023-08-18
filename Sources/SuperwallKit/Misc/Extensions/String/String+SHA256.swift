//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/08/2023.
//

import Foundation
import CommonCrypto

extension String {
  /// Creates SHA256 hash of string.
  func sha256() -> [UInt8]? {
    guard let data = data(using: .utf8) else {
      return nil
    }
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
    }
    return hash
  }

  /// Produces a number from 0 to 99 inclusive based on the SHA256 hash value
  /// of the string.
  func sha256MappedToRange() -> Int? {
    guard let hashBytes = sha256() else {
      return nil
    }

    // Break the hash into 8-byte chunks
    let chunks = stride(from: 0, to: hashBytes.count, by: 8).map {
      Array(hashBytes[$0..<$0 + 8])
    }

    // Sum the modulo 100 value of each chunk
    var sum: UInt64 = 0
    for chunk in chunks {
      let chunkValue = chunk.withUnsafeBytes { $0.load(as: UInt64.self) }
      sum = sum &+ chunkValue  // &+ ensures wrapping addition
    }

    return Int(sum % 100)
  }
}
