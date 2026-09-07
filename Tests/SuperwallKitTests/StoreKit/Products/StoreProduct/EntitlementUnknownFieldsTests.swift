//
//  EntitlementUnknownFieldsTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 07/09/2026.
//
// swiftlint:disable all

import Foundation
import Superscript
import Testing
@testable import SuperwallKit

/// An entitlement that a Purchase Controller supplies carries no renewal
/// metadata. These tests pin down that "we don't know" reaches an audience
/// filter as null rather than as an absent key, because a filter gives an
/// absent key the type default and so reads a dropped `Bool?` as `false`.
@Suite(.serialized)
struct EntitlementUnknownFieldsTests {
  /// The same trip an entitlement makes on its way to a filter:
  /// `JSONEncoder` -> `JSONSerialization` -> `[String: Any]`.
  private func encodedDictionary(_ entitlement: Entitlement) throws -> [String: Any] {
    let data = try JSONEncoder().encode(entitlement)
    let object = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
    return try #require(object as? [String: Any])
  }

  private func evaluate(_ expression: String, entitlement: Entitlement) throws -> String {
    let attributes: [String: Any] = [
      "device": [
        "customerInfo": [
          "entitlements": [try encodedDictionary(entitlement)]
        ]
      ]
    ]

    var variablesMap: [String: PassableValue] = [:]
    if case let PassableValue.map(dictionary) = toPassableValue(from: attributes) {
      variablesMap = dictionary
    }

    let executionContext = ExecutionContext(
      variables: PassableMap(map: variablesMap),
      computed: [:],
      device: [:],
      expression: expression
    )
    let jsonData = try JSONEncoder().encode(executionContext)
    let jsonString = try #require(String(data: jsonData, encoding: .utf8))

    let dependencyContainer = DependencyContainer()
    return evaluateWithContext(
      definition: jsonString,
      context: EvaluationContext(storage: dependencyContainer.storage)
    )
  }

  /// The audience from the incident: "active, and will not renew".
  private let willNotRenewFilter = """
    device.customerInfo.entitlements.exists(e, e.isActive == true && e.willRenew == false)
    """

  @Test func unknownWillRenewIsEncodedAsExplicitNull() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true)
    let dictionary = try encodedDictionary(entitlement)

    #expect(dictionary.keys.contains("willRenew"))
    #expect(dictionary["willRenew"] is NSNull)
  }

  @Test func knownWillRenewIsEncodedAsItsValue() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true, willRenew: false)
    let dictionary = try encodedDictionary(entitlement)

    #expect(dictionary["willRenew"] as? Bool == false)
  }

  /// Dates are deliberately left out rather than nulled: filters compare them
  /// with `<` and `>`, and null on either side of an ordering comparison makes
  /// the whole filter evaluate to null.
  @Test func unknownDatesAreLeftOut() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true)
    let dictionary = try encodedDictionary(entitlement)

    #expect(dictionary.keys.contains("expiresAt") == false)
    #expect(dictionary.keys.contains("startsAt") == false)
    #expect(dictionary.keys.contains("renewedAt") == false)
  }

  @Test func nsNullBecomesPassableNull() {
    if case PassableValue.null = toPassableValue(from: NSNull()) {
      return
    }
    Issue.record("Expected NSNull to become PassableValue.null")
  }

  @Test func nullSurvivesTheTripIntoTheFilterContext() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true)
    let passableValue = toPassableValue(from: try encodedDictionary(entitlement))

    guard case let PassableValue.map(dictionary) = passableValue else {
      Issue.record("Expected a map")
      return
    }
    if case PassableValue.null = try #require(dictionary["willRenew"]) {
      return
    }
    Issue.record("Expected willRenew to be PassableValue.null")
  }

  @Test func bareEntitlementDoesNotMatchWillNotRenew() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true)
    let result = try evaluate(willNotRenewFilter, entitlement: entitlement)

    #expect(result == #"{"Ok":{"type":"bool","value":false}}"#)
  }

  @Test func explicitlyNotRenewingStillMatches() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true, willRenew: false)
    let result = try evaluate(willNotRenewFilter, entitlement: entitlement)

    #expect(result == #"{"Ok":{"type":"bool","value":true}}"#)
  }

  @Test func explicitlyRenewingDoesNotMatch() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true, willRenew: true)
    let result = try evaluate(willNotRenewFilter, entitlement: entitlement)

    #expect(result == #"{"Ok":{"type":"bool","value":false}}"#)
  }

  /// A filter can still ask whether the SDK knows the renewal state.
  @Test func unknownWillRenewComparesEqualToNull() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true)
    let result = try evaluate(
      "device.customerInfo.entitlements.exists(e, e.willRenew == null)",
      entitlement: entitlement
    )

    #expect(result == #"{"Ok":{"type":"bool","value":true}}"#)
  }
}
