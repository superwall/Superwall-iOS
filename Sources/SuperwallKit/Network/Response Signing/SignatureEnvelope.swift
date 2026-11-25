//
//  SignatureEnvelope.swift
//  SuperwallKit
//
//  Created by Superwall on 19/11/2026.
//

import Foundation

/// The parsed `X-Superwall-Signature` header:
/// `v=1, t=<unix seconds>, kind=raw, cred=:<base64>:, sig=:<base64>:`.
///
/// `raw` is the only credential kind; anything else, `x509` included, is malformed.
///
/// A subset of an RFC 8941 dictionary. Members may come in any order and unknown members are
/// ignored. The format is specified in superwall/paywall-next `packages/response-signing`.
struct SignatureEnvelope: Equatable {
  static let signatureHeader = "X-Superwall-Signature"
  static let nonceHeader = "X-Superwall-Nonce"
  static let currentVersion: Int64 = 1
  static let rawKind = "raw"

  /// `Int64` on every platform, so a 15-digit version is unsupported rather than malformed on
  /// 32-bit watches too.
  let version: Int64
  let signedAt: Int64
  let credential: Data
  let signature: Data

  /// Returns `nil` for anything malformed.
  init?(header: String) {
    var members: [String: String] = [:]
    for part in header.split(separator: ",", omittingEmptySubsequences: false) {
      let member = part.trimmingCharacters(in: .whitespaces)
      guard
        let equals = member.firstIndex(of: "="),
        equals != member.startIndex
      else {
        return nil
      }
      let key = String(member[..<equals])
      guard members[key] == nil else {
        return nil
      }
      members[key] = String(member[member.index(after: equals)...])
    }

    guard
      members["kind"] == Self.rawKind,
      let version = Self.integer(members["v"]),
      let signedAt = Self.integer(members["t"]),
      let credential = Self.bytes(members["cred"]),
      let signature = Self.bytes(members["sig"])
    else {
      return nil
    }
    self.version = version
    self.signedAt = signedAt
    self.credential = credential
    self.signature = signature
  }

  /// Canonical decimal: 1–15 ASCII digits, no leading zeros.
  private static func integer(_ raw: String?) -> Int64? {
    guard let raw = raw else {
      return nil
    }
    let digits = Array(raw.utf8)
    let isDigit: (UInt8) -> Bool = { (0x30...0x39).contains($0) }
    guard
      (1...15).contains(digits.count),
      digits.allSatisfy(isDigit),
      digits.count == 1 || digits[0] != 0x30
    else {
      return nil
    }
    return Int64(raw)
  }

  /// An RFC 8941 byte sequence: padded base64 between colons.
  private static func bytes(_ raw: String?) -> Data? {
    guard
      let raw = raw,
      raw.count >= 2,
      raw.hasPrefix(":"),
      raw.hasSuffix(":")
    else {
      return nil
    }
    let base64 = String(raw.dropFirst().dropLast())
    guard base64.count % 4 == 0 else {
      return nil
    }
    return Data(base64Encoded: base64)
  }
}
