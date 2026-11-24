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
  static let currentVersion = 1
  static let rawKind = "raw"

  let version: Int
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

    func integer(_ key: String) -> Int64? {
      guard
        let raw = members[key],
        !raw.isEmpty,
        raw.count <= 15,
        raw.allSatisfy({ ("0"..."9").contains($0) })
      else {
        return nil
      }
      return Int64(raw)
    }

    func bytes(_ key: String) -> Data? {
      guard
        let raw = members[key],
        raw.count >= 2,
        raw.hasPrefix(":"),
        raw.hasSuffix(":")
      else {
        return nil
      }
      let base64 = String(raw.dropFirst().dropLast())
      // RFC 8941 byte sequences are padded base64.
      guard base64.count % 4 == 0 else {
        return nil
      }
      return Data(base64Encoded: base64)
    }

    guard
      members["kind"] == Self.rawKind,
      let version = integer("v").flatMap({ Int(exactly: $0) }),
      let signedAt = integer("t"),
      let credential = bytes("cred"),
      let signature = bytes("sig")
    else {
      return nil
    }
    self.version = version
    self.signedAt = signedAt
    self.credential = credential
    self.signature = signature
  }
}
