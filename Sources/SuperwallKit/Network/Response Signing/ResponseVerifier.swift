//
//  ResponseVerifier.swift
//  SuperwallKit
//
//  Created by Superwall on 19/11/2026.
//

import CryptoKit
import Foundation

/// Verifies `X-Superwall-Signature` on SDK responses. The format and the shared test vectors live
/// in superwall/paywall-next `packages/response-signing`; Android implements the same steps.
///
/// The response is signed by a short-lived signing key, which an embedded root authorises with a
/// raw key statement (`kind=raw`, the only kind): a fixed layout the root signs directly. There is
/// no X.509 and no intermediate, so there's nothing to parse but that layout.
final class ResponseVerifier: @unchecked Sendable {
  /// A root the SDK trusts: its 65-byte uncompressed P-256 public key (see ``ResponseSigningRoots``).
  struct TrustedRoot {
    let publicKey: Data

    var keyId: Data {
      Data(SHA256.hash(data: publicKey))
    }
  }

  enum Endpoint: String {
    case staticConfig = "static_config"
    case entitlements
  }

  /// What the response must be about, from the request this SDK sent:
  /// - `apiKey`: the public API key the request used.
  /// - `subject`: entitlements only, the user ID in the path (not URL-encoded); empty for config.
  /// - `deviceId`: entitlements only, the `deviceId` query value; empty for config.
  /// - `nonce`: the `X-Superwall-Nonce` this request sent; empty for config.
  ///
  /// Callers that enforce must also treat ``Result/unsigned`` as a failure, always send a fresh
  /// nonce for entitlements, and reject a response with more than one signature header.
  struct Context: Equatable {
    let endpoint: Endpoint
    let apiKey: String
    let subject: String
    let deviceId: String
    let nonce: String
  }

  enum Failure: String, Error {
    case malformedHeader = "malformed_header"
    case unsupportedVersion = "unsupported_version"
    case malformedCredential = "malformed_credential"
    case unknownRoot = "unknown_root"
    case invalidCredentialSignature = "invalid_credential_signature"
    case credentialNotValidAtSigningTime = "credential_not_valid_at_signing_time"
    case signedInFuture = "signed_in_future"
    case credentialExpired = "credential_expired"
    case invalidSignature = "invalid_signature"
  }

  enum Result: Equatable {
    case verified
    case unsigned
    case failed(Failure)
  }

  private struct VerifiedKey {
    let publicKey: P256.Signing.PublicKey
    let notBefore: Int64
    let notAfter: Int64
  }

  /// How far the device clock may be from the server's: a signature dated further ahead than this
  /// is rejected, and so is any response once the clock is this far past the signing key's expiry.
  /// Generous, because device clocks are often wrong; entitlements get their freshness from the
  /// nonce, not the clock.
  static let clockToleranceSeconds: Int64 = 24 * 60 * 60

  private static let statementLength = 1 + 1 + 32 + 8 + 8 + 65
  private static let keyStatementPrefix = Data("superwall-signing-key-v1\u{0}".utf8)
  private static let responsePrefix = Data("superwall-response-v1\u{0}".utf8)

  private let roots: [TrustedRoot]
  private let lock = NSLock()
  /// Verified credentials, keyed by SHA-256, so a reused credential is checked once.
  private var credentialCache: [String: VerifiedKey] = [:]
  private static let maxCachedCredentials = 8

  init(roots: [TrustedRoot] = ResponseSigningRoots.all) {
    self.roots = roots
  }

  /// - Parameters:
  ///   - header: The response's `X-Superwall-Signature`, or `nil`.
  ///   - body: The response body exactly as received, after decompression.
  ///   - now: The device's current Unix time in seconds.
  func verify(
    header: String?,
    context: Context,
    body: Data,
    now: Int64
  ) -> Result {
    guard let header = header else {
      return .unsigned
    }
    guard let envelope = SignatureEnvelope(header: header) else {
      return .failed(.malformedHeader)
    }
    guard envelope.version == SignatureEnvelope.currentVersion else {
      return .failed(.unsupportedVersion)
    }

    let credentialHash = Data(SHA256.hash(data: envelope.credential))
    let cacheKey = credentialHash.base64EncodedString()
    let key: VerifiedKey
    if let cached = lock.withLock({ credentialCache[cacheKey] }) {
      key = cached
    } else {
      switch verifyRawCredential(envelope.credential) {
      case .success(let verifiedKey):
        key = verifiedKey
      case .failure(let failure):
        return .failed(failure)
      }
    }

    if let failure = Self.timeFailure(signedAt: envelope.signedAt, key: key, now: now) {
      return .failed(failure)
    }
    // Only cache a credential once it's been used for a valid signing time.
    lock.withLock {
      if credentialCache.count >= Self.maxCachedCredentials {
        credentialCache.removeAll()
      }
      credentialCache[cacheKey] = key
    }

    let message = Self.signedMessage(
      credentialHash: credentialHash,
      signedAt: envelope.signedAt,
      context: context,
      body: body
    )
    return Self.verifyEcdsa(key.publicKey, derSignature: envelope.signature, message: message)
      ? .verified
      : .failed(.invalidSignature)
  }

  /// The signing time must be inside the key's validity and not far ahead of the device clock,
  /// and the device clock not far past the key's expiry: that bounds what a leaked signing key, or
  /// a replayed config, is good for.
  private static func timeFailure(signedAt: Int64, key: VerifiedKey, now: Int64) -> Failure? {
    if signedAt < key.notBefore || signedAt > key.notAfter {
      return .credentialNotValidAtSigningTime
    }
    if signedAt > now + clockToleranceSeconds {
      return .signedInFuture
    }
    if now - clockToleranceSeconds > key.notAfter {
      return .credentialExpired
    }
    return nil
  }

  // MARK: - Raw key statements

  /// `u8 version | u8 alg | [32] rootKeyId | i64 notBefore | i64 notAfter | [65] key`
  /// `u16 sigLen | [sigLen]` root signature over `keyStatementPrefix || statement`.
  private func verifyRawCredential(_ credential: Data) -> Swift.Result<VerifiedKey, Failure> {
    let bytes = [UInt8](credential)
    let length = Self.statementLength
    guard
      bytes.count >= length + 2,
      bytes[0] == 1,
      bytes[1] == 1
    else {
      return .failure(.malformedCredential)
    }
    let signatureLength = Int(bytes[length]) << 8 | Int(bytes[length + 1])
    guard bytes.count == length + 2 + signatureLength else {
      return .failure(.malformedCredential)
    }

    let rootKeyId = Data(bytes[2..<34])
    guard
      let root = roots.first(where: { $0.keyId == rootKeyId }),
      let rootKey = try? P256.Signing.PublicKey(x963Representation: root.publicKey)
    else {
      return .failure(.unknownRoot)
    }
    let statement = Data(bytes[0..<length])
    let rootSignature = Data(bytes[(length + 2)...])
    guard Self.verifyEcdsa(
      rootKey,
      derSignature: rootSignature,
      message: Self.keyStatementPrefix + statement
    ) else {
      return .failure(.invalidCredentialSignature)
    }
    guard let signingKey = try? P256.Signing.PublicKey(x963Representation: Data(bytes[50..<115])) else {
      return .failure(.malformedCredential)
    }
    return .success(
      VerifiedKey(
        publicKey: signingKey,
        notBefore: Self.int64(bytes, at: 34),
        notAfter: Self.int64(bytes, at: 42)
      )
    )
  }

  private static func int64(_ bytes: [UInt8], at offset: Int) -> Int64 {
    var value: UInt64 = 0
    for byte in bytes[offset..<(offset + 8)] {
      value = value << 8 | UInt64(byte)
    }
    return Int64(bitPattern: value)
  }

  // MARK: - Signed message

  static func signedMessage(
    credentialHash: Data,
    signedAt: Int64,
    context: Context,
    body: Data
  ) -> Data {
    var message = responsePrefix
    let fields: [Data] = [
      credentialHash,
      Data(String(signedAt).utf8),
      Data(context.endpoint.rawValue.utf8),
      Data(context.apiKey.utf8),
      Data(context.subject.utf8),
      Data(context.deviceId.utf8),
      Data(context.nonce.utf8),
      Data(SHA256.hash(data: body))
    ]
    for field in fields {
      let length = UInt32(field.count).bigEndian
      withUnsafeBytes(of: length) { message.append(contentsOf: $0) }
      message.append(field)
    }
    return message
  }

  /// ECDSA P-256 / SHA-256 with a DER signature. Malformed input is `false`.
  static func verifyEcdsa(
    _ publicKey: P256.Signing.PublicKey,
    derSignature: Data,
    message: Data
  ) -> Bool {
    guard let signature = try? P256.Signing.ECDSASignature(derRepresentation: derSignature) else {
      return false
    }
    return publicKey.isValidSignature(signature, for: message)
  }
}
