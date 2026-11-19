//
//  SignatureEnvelope.swift
//  SuperwallKit
//
//  Created by Superwall on 19/11/2026.
//

import Foundation

/// The parsed `X-Superwall-Signature` header:
/// `v=1, t=<unix seconds>, kind=x509|raw, cred=:<base64>:, sig=:<base64>:`.
///
/// A subset of an RFC 8941 dictionary. Members may come in any order and unknown members are
/// ignored. The format is specified in superwall/paywall-next `packages/response-signing`.
struct SignatureEnvelope: Equatable {
  enum CredentialKind: String {
    case x509
    case raw
  }

  static let signatureHeader = "X-Superwall-Signature"
  static let nonceHeader = "X-Superwall-Nonce"
  static let currentVersion = 1

  let version: Int
  let signedAt: Int64
  let kind: CredentialKind
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
      let kind = members["kind"].flatMap(CredentialKind.init(rawValue:)),
      let version = integer("v"),
      let signedAt = integer("t"),
      let credential = bytes("cred"),
      let signature = bytes("sig")
    else {
      return nil
    }
    self.version = Int(version)
    self.signedAt = signedAt
    self.kind = kind
    self.credential = credential
    self.signature = signature
  }
}
