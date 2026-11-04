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
  private func encodedDictionary(
    _ entitlement: Entitlement,
    reportingUnknownFieldsAsNull: Bool = true
  ) throws -> [String: Any] {
    let encoder = reportingUnknownFieldsAsNull
      ? JSONEncoder.reportingUnknownFieldsAsNull()
      : JSONEncoder()
    let data = try encoder.encode(entitlement)
    let object = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
    return try #require(object as? [String: Any])
  }

  /// One container for the suite: building one spins up real storage and a
  /// persistent container, which the sibling `CELEvaluatorTests` resets for the
  /// same reason.
  private static let dependencyContainer: DependencyContainer = {
    let container = DependencyContainer()
    container.storage.reset()
    return container
  }()

  private func evaluate(_ expression: String, entitlement: Entitlement) throws -> Bool {
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

    // Mirrors what CELEvaluator passes in production.
    let computedProperties = Dictionary(uniqueKeysWithValues:
      ComputedPropertyRequestType.allCases.map {
        ($0.description, [PassableValue.string("event_name")])
      }
    )
    let executionContext = ExecutionContext(
      variables: PassableMap(map: variablesMap),
      computed: computedProperties,
      device: computedProperties,
      expression: expression
    )
    let jsonData = try JSONEncoder().encode(executionContext)
    let jsonString = try #require(String(data: jsonData, encoding: .utf8))

    let output = evaluateWithContext(
      definition: jsonString,
      context: EvaluationContext(storage: Self.dependencyContainer.storage)
    )

    // Decoded rather than compared byte for byte, so a future Superscript bump
    // that reshapes the wrapper doesn't read as a behaviour change.
    let outputData = try #require(output.data(using: .utf8))
    let result = try JSONDecoder().decode(EvaluationResult.self, from: outputData)
    guard case let .success(value) = result,
      case let .bool(matched) = value else {
      Issue.record("Expected a boolean result, got \(output)")
      return false
    }
    return matched
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

  /// Everything that isn't an audience filter keeps the shape it always had, so
  /// the enrichment request, paywall variables, session attributes and
  /// `getDeviceAttributes()` don't start carrying nulls.
  @Test func unknownFieldsStayOmittedForEveryOtherConsumer() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true)
    let dictionary = try encodedDictionary(entitlement, reportingUnknownFieldsAsNull: false)

    for key in ["willRenew", "isLifetime", "state", "offerType", "latestProductId", "store"] {
      #expect(dictionary.keys.contains(key) == false, "\(key) should be omitted")
    }
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

  /// The flag is set on the encoder for the whole device template, and the
  /// entitlements sit two levels down inside it. This pins that `userInfo`
  /// reaches a nested encoder, which is what the wiring depends on.
  @Test func theNullFlagReachesNestedEntitlements() throws {
    let customerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [Entitlement(id: "unlimited_access", isActive: true)],
      isPlaceholder: false
    )

    func willRenewEntry(using encoder: JSONEncoder) throws -> (present: Bool, isNull: Bool) {
      let data = try encoder.encode(customerInfo)
      let object = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
      let dictionary = try #require(object as? [String: Any])
      let entitlements = try #require(dictionary["entitlements"] as? [[String: Any]])
      let entitlement = try #require(entitlements.first)
      return (entitlement.keys.contains("willRenew"), entitlement["willRenew"] is NSNull)
    }

    let forFilters = try willRenewEntry(using: .reportingUnknownFieldsAsNull())
    #expect(forFilters.present)
    #expect(forFilters.isNull)

    let forEveryoneElse = try willRenewEntry(using: JSONEncoder())
    #expect(forEveryoneElse.present == false)
  }

  /// Runs the real production call rather than a hand-built encoder, so that
  /// removing `reportingUnknownFieldsAsNull: true` from
  /// `makeAudienceFilterAttributes` fails a test instead of silently restoring
  /// the incident. That one argument is the whole opt-in.
  @Test func onlyTheAudienceFilterPathReportsUnknownFieldsAsNull() async throws {
    let container = DependencyContainer()
    let previous = Superwall.shared.customerInfo
    defer { Superwall.shared.customerInfo = previous }

    Superwall.shared.customerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: [Entitlement(id: "unlimited_access", isActive: true)],
      isPlaceholder: false
    )

    func willRenewEntry(in device: [String: Any]) throws -> (present: Bool, isNull: Bool) {
      let customerInfo = try #require(device["customerInfo"] as? [String: Any])
      let entitlements = try #require(customerInfo["entitlements"] as? [[String: Any]])
      let entitlement = try #require(
        entitlements.first { $0["identifier"] as? String == "unlimited_access" }
      )
      return (entitlement.keys.contains("willRenew"), entitlement["willRenew"] is NSNull)
    }

    let filterAttributes = await container.makeAudienceFilterAttributes(
      forPlacement: nil,
      withComputedProperties: []
    )
    let filterDevice = try #require(filterAttributes["device"] as? [String: Any])
    let forFilters = try willRenewEntry(in: filterDevice)
    #expect(forFilters.present)
    #expect(forFilters.isNull)

    // The same data on the way to every other consumer keeps its old shape.
    let template = await container.deviceHelper.getTemplateDevice()
    #expect(try willRenewEntry(in: template).present == false)
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
    #expect(try evaluate(willNotRenewFilter, entitlement: entitlement) == false)
  }

  @Test func explicitlyNotRenewingStillMatches() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true, willRenew: false)
    #expect(try evaluate(willNotRenewFilter, entitlement: entitlement) == true)
  }

  @Test func explicitlyRenewingDoesNotMatch() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true, willRenew: true)
    #expect(try evaluate(willNotRenewFilter, entitlement: entitlement) == false)
  }

  /// The string-valued fields are nulled too, so equality against them has to
  /// stay a plain no-match rather than becoming an error or a null that would
  /// take the rest of the filter with it.
  @Test(arguments: [
    "device.customerInfo.entitlements.exists(e, e.store == \"APP_STORE\")",
    "device.customerInfo.entitlements.exists(e, e.state == \"SUBSCRIBED\")",
    "device.customerInfo.entitlements.exists(e, e.latestProductId == \"pro_yearly\")",
    "device.customerInfo.entitlements.exists(e, e.isLifetime == true)"
  ])
  func unknownStringFieldsDoNotMatch(expression: String) throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true)

    #expect(try evaluate(expression, entitlement: entitlement) == false)
  }

  /// The whole point of the change: the field is now present, so a filter can
  /// tell that the SDK holds no opinion rather than reading a default.
  @Test func unknownWillRenewIsReportedAsPresent() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true)

    #expect(
      try evaluate(
        "device.customerInfo.entitlements.exists(e, has(e.willRenew))",
        entitlement: entitlement
      ) == true
    )
  }

  /// A filter can still ask whether the SDK knows the renewal state.
  @Test func unknownWillRenewComparesEqualToNull() throws {
    let entitlement = Entitlement(id: "unlimited_access", isActive: true)
    #expect(
      try evaluate(
        "device.customerInfo.entitlements.exists(e, e.willRenew == null)",
        entitlement: entitlement
      ) == true
    )
  }
}
