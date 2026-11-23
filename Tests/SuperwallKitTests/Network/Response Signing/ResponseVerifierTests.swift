//
//  ResponseVerifierTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 19/11/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

private struct Vectors: Decodable {
  struct Root: Decodable {
    let publicKey: String
    let certificate: String
  }

  struct Case: Decodable {
    struct Context: Decodable {
      let endpoint: String
      let apiKey: String
      let subject: String
      let deviceId: String
      let nonce: String
    }

    struct Expected: Decodable {
      let status: String
      let reason: String?
    }

    let name: String
    let now: Int64
    let context: Context
    let body: String
    let header: String?
    let expected: Expected
    let reasonIsPortable: Bool
  }

  let roots: [Root]
  let cases: [Case]

  static let shared: Vectors = {
    // swiftlint:disable:next force_try
    try! JSONDecoder().decode(Vectors.self, from: Data(responseSigningVectorsJSON.utf8))
  }()

  var trustedRoots: [ResponseVerifier.TrustedRoot] {
    roots.map {
      ResponseVerifier.TrustedRoot(
        publicKey: Data(base64Encoded: $0.publicKey) ?? Data(),
        certificate: Data(base64Encoded: $0.certificate) ?? Data()
      )
    }
  }
}

private extension Vectors.Case {
  var verifierContext: ResponseVerifier.Context? {
    ResponseVerifier.Endpoint(rawValue: context.endpoint).map {
      ResponseVerifier.Context(
        endpoint: $0,
        apiKey: context.apiKey,
        subject: context.subject,
        deviceId: context.deviceId,
        nonce: context.nonce
      )
    }
  }
}

struct ResponseVerifierTests {
  @Test("there are vectors for both credential kinds")
  func vectorsAreLoaded() {
    let names = Vectors.shared.cases.map(\.name)
    #expect(names.count >= 39)
    #expect(names.contains("x509_entitlements_verified"))
    #expect(names.contains("raw_entitlements_verified"))
  }

  @Test(
    "every shared vector reaches the expected result",
    arguments: Vectors.shared.cases.map(\.name)
  )
  func vector(named name: String) throws {
    let vector = try #require(Vectors.shared.cases.first { $0.name == name })
    let context = try #require(vector.verifierContext)
    let verifier = ResponseVerifier(roots: Vectors.shared.trustedRoots)

    let result = verifier.verify(
      header: vector.header,
      context: context,
      body: Data(base64Encoded: vector.body) ?? Data(),
      now: vector.now
    )

    switch vector.expected.status {
    case "verified":
      #expect(result == .verified)
    case "unsigned":
      #expect(result == .unsigned)
    default:
      guard case .failed(let failure) = result else {
        Issue.record("Expected a failure, got \(result)")
        return
      }
      if vector.reasonIsPortable {
        #expect(failure.rawValue == vector.expected.reason)
      }
    }
  }

  @Test("a credential that verified once is reused, and still binds the subject")
  func credentialCache() throws {
    let vector = try #require(Vectors.shared.cases.first { $0.name == "x509_entitlements_verified" })
    let context = try #require(vector.verifierContext)
    let body = Data(base64Encoded: vector.body) ?? Data()
    let verifier = ResponseVerifier(roots: Vectors.shared.trustedRoots)

    for _ in 0..<2 {
      #expect(verifier.verify(header: vector.header, context: context, body: body, now: vector.now) == .verified)
    }
    let otherUser = ResponseVerifier.Context(
      endpoint: context.endpoint,
      apiKey: context.apiKey,
      subject: "user_456",
      deviceId: context.deviceId,
      nonce: context.nonce
    )
    #expect(
      verifier.verify(header: vector.header, context: otherUser, body: body, now: vector.now)
        == .failed(.invalidSignature)
    )
  }

  @Test("no embedded roots means nothing verifies")
  func noRoots() throws {
    let vector = try #require(Vectors.shared.cases.first { $0.name == "raw_entitlements_verified" })
    let context = try #require(vector.verifierContext)
    let result = ResponseVerifier(roots: []).verify(
      header: vector.header,
      context: context,
      body: Data(base64Encoded: vector.body) ?? Data(),
      now: vector.now
    )
    #expect(result == .failed(.unknownRoot))
  }

  @Test("header members may come in any order, and unknown ones are ignored")
  func headerOrder() throws {
    let envelope = try #require(
      SignatureEnvelope(header: "sig=:AQ==:,future=1, cred=:AgM=:, kind=raw, t=12, v=1")
    )
    #expect(envelope.version == 1)
    #expect(envelope.signedAt == 12)
    #expect(envelope.kind == .raw)
    #expect(envelope.credential == Data([2, 3]))
    #expect(SignatureEnvelope(header: "v=1, v=1, t=1, kind=raw, cred=:AA==:, sig=:AA==:") == nil)
    #expect(SignatureEnvelope(header: "v=1, t=-1, kind=raw, cred=:AA==:, sig=:AA==:") == nil)
    #expect(SignatureEnvelope(header: "v=1, t=1, kind=raw, cred=:AQI:, sig=:AA==:") == nil)
  }

  @Test("malformed DER is rejected without trapping, on 32-bit platforms too")
  func malformedDER() {
    let inputs: [[UInt8]] = [
      [0x30, 0x84, 0x80, 0x00, 0x00, 0x00], // length wraps negative in a 32-bit Int
      [0x30, 0x84, 0x7f, 0xff, 0xff, 0xff], // length overflows position + length
      [0x30, 0x85, 0x01, 0x00, 0x00, 0x00, 0x00], // five length bytes
      [0x30, 0x80], // indefinite length
      [0x30, 0x82, 0x01], // truncated length
      [0x30, 0x05, 0x01], // value shorter than its length
      [0x30],
      []
    ]
    for input in inputs {
      var reader = DERReader(input)
      #expect(reader.read(tag: 0x30) == nil)
      #expect(CertificateFields(der: Data(input)) == nil)
    }
  }

  @Test("a version too large for Int is malformed, not a trap")
  func hugeVersion() {
    // 64-bit: an unsupported version. 32-bit (arm64_32 watches): too large for Int, so malformed.
    let result = ResponseVerifier(roots: []).verify(
      header: "v=999999999999999, t=1, kind=raw, cred=:AA==:, sig=:AA==:",
      context: ResponseVerifier.Context(
        endpoint: .entitlements,
        apiKey: "pk",
        subject: "u",
        deviceId: "",
        nonce: "n"
      ),
      body: Data(),
      now: 0
    )
    #expect(result == .failed(.unsupportedVersion) || result == .failed(.malformedHeader))
  }

  @Test("certificate validity is read in UTC from both time formats")
  func certificateTimes() {
    // UTCTime 261119100000Z and GeneralizedTime 20500101000000Z.
    var reader = DERReader(
      [0x17, 0x0d] + Array("261119100000Z".utf8) + [0x18, 0x0f] + Array("20500101000000Z".utf8)
    )
    #expect(reader.readTime() == 1_795_082_400)
    #expect(reader.readTime() == 2_524_608_000)
    #expect(reader.isAtEnd)
  }
}
