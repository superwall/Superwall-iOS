//
//  ResponseSignatureCheck.swift
//  SuperwallKit
//
//  Created by Superwall on 25/11/2026.
//

import CryptoKit
import Foundation

/// What a signed endpoint's response must be about, apart from the API key and nonce, which come
/// from the request as sent.
struct SignedResponse: Equatable {
  let endpoint: ResponseVerifier.Endpoint
  /// Entitlements: the user ID in the path, not URL-encoded. Redemption: the request body's
  /// SHA-256 in lowercase hex. Empty for config.
  let subject: String
  /// Entitlements: the `deviceId` query value. Empty otherwise.
  let deviceId: String

  /// Whether the request sends a nonce: every signed endpoint but config, which is cached.
  var takesNonce: Bool {
    return endpoint != .staticConfig
  }

  static let staticConfig = SignedResponse(endpoint: .staticConfig, subject: "", deviceId: "")

  /// A redemption response, bound to the SHA-256 of `body`, the exact bytes sent: a request
  /// changed on the way (another user, device or code) won't verify.
  static func forRequestBody(_ endpoint: ResponseVerifier.Endpoint, body: Data?) -> SignedResponse {
    let hash = SHA256.hash(data: body ?? Data())
      .map { String(format: "%02x", $0) }
      .joined()
    return SignedResponse(endpoint: endpoint, subject: hash, deviceId: "")
  }
}

/// Ties ``ResponseVerifier`` to the SDK's requests: the nonce on entitlements requests, the
/// context a response is checked against, and what a result means for the request.
///
/// Signatures are checked on every signed response. By default a failure is only reported, and the
/// response is used as before; with ``SuperwallOptions/shouldEnforceResponseSignatures`` a response
/// that isn't verified, an unsigned one included, fails like a network error.
enum ResponseSignatureCheck {
  /// What to do with a response.
  enum Decision: Equatable {
    /// Use it, saying nothing.
    case accept
    /// Use it, and report why it didn't verify.
    case report(reason: String)
    /// Don't use it: fail the request like a network error, and report why.
    case reject(reason: String)
  }

  /// Adds a fresh `X-Superwall-Nonce` to a request and keeps the URL cache out of it, since a
  /// cached response would carry an earlier request's nonce. Returns the nonce, or an empty
  /// string for config, which is signed without one. Call it for every attempt.
  static func prepare(_ request: inout URLRequest, for signed: SignedResponse) -> String {
    guard signed.takesNonce else {
      return ""
    }
    let nonce = makeNonce()
    request.setValue(nonce, forHTTPHeaderField: SignatureEnvelope.nonceHeader)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    return nonce
  }

  /// 16 random bytes, base64url without padding (22 characters).
  static func makeNonce() -> String {
    var generator = SystemRandomNumberGenerator()
    let bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
    return Data(bytes)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  /// What the response must be about. The API key is read from the request as sent (config's
  /// `pk`, entitlements' bearer token), since that's what the server binds. `nil` when the request
  /// doesn't carry one.
  static func context(
    for signed: SignedResponse,
    request: URLRequest,
    nonce: String
  ) -> ResponseVerifier.Context? {
    let apiKey: String?
    switch signed.endpoint {
    case .staticConfig:
      apiKey = request.url
        .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
        .queryItems?
        .first { $0.name == "pk" }?
        .value
    case .entitlements,
      .redeem,
      .pollRedemptionResult:
      apiKey = request.value(forHTTPHeaderField: "Authorization")
        .flatMap(bearerToken)
    }
    guard let apiKey = apiKey, !apiKey.isEmpty else {
      return nil
    }
    return ResponseVerifier.Context(
      endpoint: signed.endpoint,
      apiKey: apiKey,
      subject: signed.subject,
      deviceId: signed.deviceId,
      nonce: nonce
    )
  }

  private static func bearerToken(_ authorization: String) -> String? {
    let prefix = "Bearer "
    guard authorization.hasPrefix(prefix) else {
      return nil
    }
    return String(authorization.dropFirst(prefix.count))
  }

  /// What a verification result means for the request.
  ///
  /// - Parameter reportUnsigned: Whether an unsigned response is worth reporting when not
  ///   enforcing: only once roots are embedded, since until then the backend doesn't sign at all.
  ///   Reporting it shows a stripped header before apps enforce.
  static func decide(
    _ result: ResponseVerifier.Result,
    enforce: Bool,
    reportUnsigned: Bool = false
  ) -> Decision {
    switch result {
    case .verified:
      return .accept
    case .unsigned:
      if enforce {
        return .reject(reason: "unsigned")
      }
      return reportUnsigned ? .report(reason: "unsigned") : .accept
    case .failed(let failure):
      return enforce ? .reject(reason: failure.rawValue) : .report(reason: failure.rawValue)
    }
  }
}

/// Sent when a signed response doesn't verify. Private: it isn't passed to the delegate and can't
/// trigger a paywall. It carries the reason only, never the response.
struct ResponseSignatureFailure: Trackable {
  let endpoint: ResponseVerifier.Endpoint
  let reason: String
  let isEnforced: Bool

  let rawName = "response_signature_failed"
  let audienceFilterParams: [String: Any] = [:]
  let canImplicitlyTriggerPaywall = false

  func getSuperwallParameters() async -> [String: Any] {
    return [
      "endpoint": endpoint.rawValue,
      "reason": reason,
      "is_enforced": isEnforced
    ]
  }
}
