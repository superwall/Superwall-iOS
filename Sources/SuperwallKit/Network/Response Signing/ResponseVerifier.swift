//
//  ResponseVerifier.swift
//  SuperwallKit
//
//  Created by Superwall on 19/11/2026.
//
// swiftlint:disable type_body_length

import CryptoKit
import Foundation
import Security

/// Verifies `X-Superwall-Signature` on SDK responses. The format and the shared test vectors live
/// in superwall/paywall-next `packages/response-signing`; Android implements the same steps.
///
/// The signing key is authorised by an embedded root, either through an X.509 certificate or a
/// raw key statement (`kind`). Both give a ``VerifiedKey``; checking the response signature is the
/// same for both, so the backend can move between them without an SDK release.
final class ResponseVerifier: @unchecked Sendable {
  /// A root the SDK trusts: its 65-byte uncompressed P-256 public key and self-signed certificate.
  struct TrustedRoot {
    let publicKey: Data
    let certificate: Data

    var keyId: Data {
      Data(SHA256.hash(data: publicKey))
    }
  }

  enum Endpoint: String {
    case staticConfig = "static_config"
    case entitlements
  }

  /// What the response is about. `subject` is the public API key for config, and the user ID in
  /// the path for entitlements. `nonce` is the request's `X-Superwall-Nonce`, or empty.
  struct Context: Equatable {
    let endpoint: Endpoint
    let subject: String
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

  /// Signatures dated further ahead than this, by the device's clock, are rejected.
  static let maxClockSkewSeconds: Int64 = 5 * 60

  private static let statementLength = 1 + 1 + 32 + 8 + 8 + 65
  private static let keyStatementPrefix = Data("superwall-signing-key-v1\u{0}".utf8)
  private static let responsePrefix = Data("superwall-response-v1\u{0}".utf8)

  private let roots: [TrustedRoot]
  private let anchors: [SecCertificate]
  private let lock = NSLock()
  /// Verified credentials, keyed by kind and SHA-256, so a reused credential is checked once.
  private var credentialCache: [String: VerifiedKey] = [:]
  private static let maxCachedCredentials = 8

  init(roots: [TrustedRoot]) {
    self.roots = roots
    self.anchors = roots.compactMap {
      SecCertificateCreateWithData(nil, $0.certificate as CFData)
    }
  }

  /// - Parameters:
  ///   - header: The response's `X-Superwall-Signature`, or `nil`.
  ///   - body: The response body exactly as received, after decompression.
  ///   - now: The device's current Unix time in seconds.
  ///
  /// Certificate validation can take a few milliseconds, so don't call this on the main thread.
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
    let cacheKey = "\(envelope.kind.rawValue):\(credentialHash.base64EncodedString())"
    let key: VerifiedKey
    if let cached = lock.withLock({ credentialCache[cacheKey] }) {
      key = cached
    } else {
      let verified: Swift.Result<VerifiedKey, Failure>
      switch envelope.kind {
      case .raw:
        verified = verifyRawCredential(envelope.credential)
      case .x509:
        verified = verifyX509Credential(envelope.credential, signedAt: envelope.signedAt)
      }
      switch verified {
      case .success(let verifiedKey):
        key = verifiedKey
      case .failure(let failure):
        return .failed(failure)
      }
    }

    guard
      envelope.signedAt >= key.notBefore,
      envelope.signedAt <= key.notAfter
    else {
      return .failed(.credentialNotValidAtSigningTime)
    }
    guard envelope.signedAt <= now + Self.maxClockSkewSeconds else {
      return .failed(.signedInFuture)
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

  // MARK: - X.509

  /// Validates the certificate against the embedded roots at the signing time, with network
  /// fetches off: there's no CRL or OCSP for these certificates, and a lookup could hang.
  private func verifyX509Credential(
    _ credential: Data,
    signedAt: Int64
  ) -> Swift.Result<VerifiedKey, Failure> {
    guard
      let fields = CertificateFields(der: credential),
      let certificate = SecCertificateCreateWithData(nil, credential as CFData)
    else {
      return .failure(.malformedCredential)
    }
    // A CA certificate never signs responses, a trusted root included.
    guard
      !fields.isCA,
      !roots.contains(where: { $0.certificate == credential })
    else {
      return .failure(.malformedCredential)
    }
    guard !anchors.isEmpty else {
      return .failure(.unknownRoot)
    }

    var trust: SecTrust?
    guard
      SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust) == errSecSuccess,
      let trust = trust,
      SecTrustSetAnchorCertificates(trust, anchors as CFArray) == errSecSuccess,
      SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess,
      SecTrustSetNetworkFetchAllowed(trust, false) == errSecSuccess,
      SecTrustSetVerifyDate(
        trust,
        Date(timeIntervalSince1970: TimeInterval(signedAt)) as CFDate
      ) == errSecSuccess
    else {
      return .failure(.malformedCredential)
    }
    guard SecTrustEvaluateWithError(trust, nil) else {
      return .failure(.invalidCredentialSignature)
    }
    guard
      let secKey = SecTrustCopyKey(trust),
      let external = SecKeyCopyExternalRepresentation(secKey, nil) as Data?,
      let publicKey = try? P256.Signing.PublicKey(x963Representation: external)
    else {
      return .failure(.malformedCredential)
    }
    return .success(
      VerifiedKey(
        publicKey: publicKey,
        notBefore: fields.notBefore,
        notAfter: fields.notAfter
      )
    )
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
      Data(context.subject.utf8),
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

// MARK: - Certificate fields

/// The validity and CA flag of a certificate. `Security` has no API for these on every platform,
/// so the few fields are read from the DER directly.
struct CertificateFields {
  let notBefore: Int64
  let notAfter: Int64
  let isCA: Bool

  init?(der: Data) {
    var outer = DERReader(Array(der))
    guard
      let certificateBytes = outer.read(tag: 0x30),
      outer.isAtEnd
    else {
      return nil
    }
    var certificate = DERReader(certificateBytes)
    guard let tbsBytes = certificate.read(tag: 0x30) else {
      return nil
    }
    var tbs = DERReader(tbsBytes)
    guard
      tbs.read(tag: 0xa0) != nil, // version
      tbs.read(tag: 0x02) != nil, // serial
      tbs.read(tag: 0x30) != nil, // signature algorithm
      tbs.read(tag: 0x30) != nil, // issuer
      let validityBytes = tbs.read(tag: 0x30)
    else {
      return nil
    }
    var validity = DERReader(validityBytes)
    guard
      let notBefore = validity.readTime(),
      let notAfter = validity.readTime(),
      tbs.read(tag: 0x30) != nil, // subject
      tbs.read(tag: 0x30) != nil, // subject public key info
      let extensionsWrapper = tbs.read(tag: 0xa3)
    else {
      return nil
    }
    self.notBefore = notBefore
    self.notAfter = notAfter

    var wrapper = DERReader(extensionsWrapper)
    guard
      let extensions = wrapper.read(tag: 0x30),
      let isCA = Self.isCertificateAuthority(extensions: extensions)
    else {
      return nil
    }
    self.isCA = isCA
  }

  /// The `cA` flag of the basic constraints extension, `false` when it's absent.
  private static func isCertificateAuthority(extensions: [UInt8]) -> Bool? {
    var reader = DERReader(extensions)
    let basicConstraints: [UInt8] = [0x55, 0x1d, 0x13]
    while let extensionBytes = reader.read(tag: 0x30) {
      var item = DERReader(extensionBytes)
      guard let oid = item.read(tag: 0x06) else {
        return nil
      }
      guard oid == basicConstraints else {
        continue
      }
      _ = item.read(tag: 0x01) // critical, optional
      guard let value = item.read(tag: 0x04) else {
        return nil
      }
      var valueReader = DERReader(value)
      guard let constraints = valueReader.read(tag: 0x30) else {
        return nil
      }
      var constraintsReader = DERReader(constraints)
      return constraintsReader.read(tag: 0x01).map { $0.first.map { $0 != 0 } ?? false } ?? false
    }
    return false
  }
}

/// Reads definite-length DER TLVs with single-byte tags. A read that doesn't match leaves the
/// position where it was.
struct DERReader {
  private let bytes: [UInt8]
  private var offset = 0

  init(_ bytes: [UInt8]) {
    self.bytes = bytes
  }

  var isAtEnd: Bool {
    offset == bytes.count
  }

  mutating func read(tag: UInt8) -> [UInt8]? {
    var position = offset
    guard
      position + 2 <= bytes.count,
      bytes[position] == tag
    else {
      return nil
    }
    position += 1
    var length = Int(bytes[position])
    position += 1
    if length & 0x80 != 0 {
      let count = length & 0x7f
      guard
        count > 0,
        count <= 4,
        position + count <= bytes.count
      else {
        return nil
      }
      length = 0
      for _ in 0..<count {
        length = length << 8 | Int(bytes[position])
        position += 1
      }
    }
    guard position + length <= bytes.count else {
      return nil
    }
    offset = position + length
    return Array(bytes[position..<(position + length)])
  }

  /// UTCTime (years 1950–2049) or GeneralizedTime, as Unix seconds.
  mutating func readTime() -> Int64? {
    let text: String
    if let utc = read(tag: 0x17) {
      guard let value = String(bytes: utc, encoding: .ascii), value.count == 13 else {
        return nil
      }
      let year = Int(value.prefix(2)) ?? 0
      text = (year >= 50 ? "19" : "20") + value
    } else if let generalized = read(tag: 0x18) {
      guard let value = String(bytes: generalized, encoding: .ascii) else {
        return nil
      }
      text = value
    } else {
      return nil
    }
    let digits = Array(text.dropLast())
    guard
      text.count == 15,
      text.hasSuffix("Z"),
      digits.allSatisfy({ $0.isASCII && $0.isNumber })
    else {
      return nil
    }
    func field(_ start: Int, _ length: Int) -> Int {
      Int(String(digits[start..<(start + length)])) ?? 0
    }
    var components = DateComponents()
    components.year = field(0, 4)
    components.month = field(4, 2)
    components.day = field(6, 2)
    components.hour = field(8, 2)
    components.minute = field(10, 2)
    components.second = field(12, 2)
    var calendar = Calendar(identifier: .gregorian)
    guard let utc = TimeZone(identifier: "UTC") else {
      return nil
    }
    calendar.timeZone = utc
    guard let date = calendar.date(from: components) else {
      return nil
    }
    return Int64(date.timeIntervalSince1970)
  }
}
