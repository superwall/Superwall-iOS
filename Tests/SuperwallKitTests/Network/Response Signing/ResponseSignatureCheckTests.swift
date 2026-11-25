//
//  ResponseSignatureCheckTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 25/11/2026.
//

import Foundation
import Testing
@testable import SuperwallKit

struct ResponseSignatureCheckTests {
  private let entitlementsURL = URL(
    string: "https://subscriptions-api.superwall.com/subscriptions-api/public/v1/users/user_123/entitlements?deviceId=%24SuperwallDevice:ABC-123"
  )

  @Test("entitlements requests get a fresh base64url nonce and skip the URL cache")
  func entitlementsNonce() throws {
    let url = try #require(entitlementsURL)
    var first = URLRequest(url: url)
    var second = URLRequest(url: url)
    let signed = SignedResponse(endpoint: .entitlements, subject: "user_123", deviceId: "d")

    let nonce = ResponseSignatureCheck.prepare(&first, for: signed)
    let other = ResponseSignatureCheck.prepare(&second, for: signed)

    #expect(nonce.count == 22)
    #expect(nonce.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    #expect(nonce != other)
    #expect(first.value(forHTTPHeaderField: "X-Superwall-Nonce") == nonce)
    #expect(first.cachePolicy == .reloadIgnoringLocalCacheData)
  }

  @Test("config requests carry no nonce and keep their cache policy")
  func configHasNoNonce() throws {
    let url = try #require(URL(string: "https://api.superwall.me/api/v1/static_config?pk=pk_1"))
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadRevalidatingCacheData

    #expect(ResponseSignatureCheck.prepare(&request, for: .staticConfig).isEmpty)
    #expect(request.value(forHTTPHeaderField: "X-Superwall-Nonce") == nil)
    #expect(request.cachePolicy == .reloadRevalidatingCacheData)
  }

  @Test("the API key comes from the request as sent")
  func contextAPIKey() throws {
    let configURL = try #require(URL(string: "https://api.superwall.me/api/v1/static_config?pk=pk_1"))
    let config = ResponseSignatureCheck.context(
      for: .staticConfig,
      request: URLRequest(url: configURL),
      nonce: ""
    )
    #expect(config?.apiKey == "pk_1")
    #expect(config?.endpoint == .staticConfig)

    var entitlementsRequest = URLRequest(url: try #require(entitlementsURL))
    let signed = SignedResponse(endpoint: .entitlements, subject: "user_123", deviceId: "d")
    #expect(ResponseSignatureCheck.context(for: signed, request: entitlementsRequest, nonce: "n") == nil)
    entitlementsRequest.setValue("Bearer pk_2", forHTTPHeaderField: "Authorization")
    let entitlements = ResponseSignatureCheck.context(for: signed, request: entitlementsRequest, nonce: "n")
    #expect(entitlements?.apiKey == "pk_2")
    #expect(entitlements?.subject == "user_123")
    #expect(entitlements?.nonce == "n")
  }

  @Test("a context built from the request verifies a signed response")
  func endToEnd() throws {
    let vectors = try JSONSerialization.jsonObject(
      with: Data(responseSigningVectorsJSON.utf8)
    ) as? [String: Any]
    let roots = try #require(vectors?["roots"] as? [[String: Any]])
      .compactMap { ($0["publicKey"] as? String).flatMap { Data(base64Encoded: $0) } }
      .map { ResponseVerifier.TrustedRoot(publicKey: $0) }
    let vector = try #require(
      (vectors?["cases"] as? [[String: Any]])?.first { $0["name"] as? String == "entitlements_verified" }
    )
    let context = try #require(vector["context"] as? [String: String])

    var request = URLRequest(url: try #require(entitlementsURL))
    request.setValue("Bearer \(context["apiKey"] ?? "")", forHTTPHeaderField: "Authorization")
    let signed = SignedResponse(
      endpoint: .entitlements,
      subject: context["subject"] ?? "",
      deviceId: context["deviceId"] ?? ""
    )
    let built = try #require(
      ResponseSignatureCheck.context(for: signed, request: request, nonce: context["nonce"] ?? "")
    )

    let result = ResponseVerifier(roots: roots).verify(
      header: vector["header"] as? String,
      context: built,
      body: Data(base64Encoded: vector["body"] as? String ?? "") ?? Data(),
      now: (vector["now"] as? NSNumber)?.int64Value ?? 0
    )
    #expect(result == .verified)
  }

  @Test("report-only uses every response; enforcement rejects anything not verified")
  func decisions() {
    #expect(ResponseSignatureCheck.decide(.verified, enforce: false) == .accept)
    #expect(ResponseSignatureCheck.decide(.verified, enforce: true) == .accept)
    #expect(ResponseSignatureCheck.decide(.unsigned, enforce: false) == .accept)
    #expect(ResponseSignatureCheck.decide(.unsigned, enforce: true) == .reject(reason: "unsigned"))
    #expect(
      ResponseSignatureCheck.decide(.failed(.invalidSignature), enforce: false)
        == .report(reason: "invalid_signature")
    )
    #expect(
      ResponseSignatureCheck.decide(.failed(.unknownRoot), enforce: true)
        == .reject(reason: "unknown_root")
    )
  }

  @Test("the failure event carries the reason only and can't trigger a paywall")
  func failureEvent() async {
    let event = ResponseSignatureFailure(
      endpoint: .entitlements,
      reason: "invalid_signature",
      isEnforced: false
    )
    let parameters = await event.getSuperwallParameters()
    #expect(event.rawName == "response_signature_failed")
    #expect(!event.canImplicitlyTriggerPaywall)
    #expect(parameters["endpoint"] as? String == "entitlements")
    #expect(parameters["reason"] as? String == "invalid_signature")
    #expect(parameters["is_enforced"] as? Bool == false)
    #expect(parameters.count == 3)
  }

  @Test("signatures aren't enforced unless the app opts in")
  func enforcementIsOffByDefault() {
    let options = SuperwallOptions()
    #expect(!options.shouldEnforceResponseSignatures)
    #expect(options.toDictionary()["shouldEnforceResponseSignatures"] as? Bool == false)
  }

  @Test("config and entitlements endpoints are signed; others aren't")
  func signedEndpoints() {
    let config = Endpoint<EndpointKinds.Superwall, Config>.config(maxRetry: 1, apiKey: "pk_1", timeout: nil)
    #expect(config.signedAs == .staticConfig)
    let entitlements = Endpoint<EndpointKinds.SubscriptionsAPI, EntitlementsResponse>.entitlements(
      appUserId: nil,
      deviceId: "$SuperwallDevice:1"
    )
    #expect(
      entitlements.signedAs
        == SignedResponse(endpoint: .entitlements, subject: "$SuperwallDevice:1", deviceId: "$SuperwallDevice:1")
    )
    #expect(Endpoint<EndpointKinds.Superwall, PostbackAssignmentWrapper>.assignments().signedAs == nil)
  }
}
