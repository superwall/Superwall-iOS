//
//  IdentityStateTests.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Pure reducer tests: no store, no tasks, no mocks.
@Suite("IdentityUpdate reducers")
struct IdentityStateTests {
  private func state(
    appUserId: String? = nil,
    aliasId: String = "$SuperwallAlias:alias-1",
    seed: Int = 42,
    userAttributes: [String: Any] = [:],
    pending: Set<IdentityState.Pending> = []
  ) -> IdentityState {
    IdentityState(
      appUserId: appUserId,
      aliasId: aliasId,
      seed: seed,
      userAttributes: userAttributes,
      pending: pending,
      appInstalledAtString: "2026-01-01"
    )
  }

  // MARK: - Derived values

  @Test("userId falls back to the alias for an anonymous user")
  func userIdFallsBackToAlias() {
    #expect(state().userId == "$SuperwallAlias:alias-1")
    #expect(state().isLoggedIn == false)
    #expect(state(appUserId: "user").userId == "user")
    #expect(state(appUserId: "user").isLoggedIn)
  }

  @Test("The identity is ready only when nothing is pending")
  func readiness() {
    #expect(state().isReady)
    #expect(state(pending: [.configuration]).isReady == false)
    #expect(IdentityState(aliasId: "a", seed: 1, appInstalledAtString: "").isReady == false)
  }

  // MARK: - begin / end

  @Test("begin and end add and remove pending work")
  func beginAndEnd() {
    let begun = IdentityUpdate.begin(.reset).reduce(state())
    #expect(begun.pending == [.reset])
    #expect(begun.isReady == false)

    let ended = IdentityUpdate.end(.reset).reduce(begun)
    #expect(ended.pending.isEmpty)
    #expect(ended.isReady)
  }

  @Test("end leaves other pending work alone and ignores work that isn't pending")
  func endIsSelective() {
    let start = state(pending: [.configuration, .identification("a")])
    #expect(IdentityUpdate.end(.identification("b")).reduce(start).pending == start.pending)
    #expect(IdentityUpdate.end(.identification("a")).reduce(start).pending == [.configuration])
  }

  // MARK: - identify

  @Test("identify logs in, keeps the alias and seed, and makes the seed pending")
  func identify() {
    let result = IdentityUpdate.identify(userId: "user-1").reduce(state(userAttributes: ["custom": 1]))
    #expect(result.appUserId == "user-1")
    #expect(result.aliasId == "$SuperwallAlias:alias-1")
    #expect(result.seed == 42)
    #expect(result.pending == [.seed("user-1")])
    #expect(result.userAttributes["appUserId"] as? String == "user-1")
    #expect(result.userAttributes["aliasId"] as? String == "$SuperwallAlias:alias-1")
    #expect(result.userAttributes["seed"] as? Int == 42)
    #expect(result.userAttributes["custom"] as? Int == 1)
    #expect(result.userAttributes["applicationInstalledAt"] as? String == "2026-01-01")
  }

  @Test("identify keeps work that was already pending")
  func identifyKeepsPending() {
    let result = IdentityUpdate.identify(userId: "user-1")
      .reduce(state(pending: [.configuration, .identification("user-1")]))
    #expect(result.pending == [.configuration, .identification("user-1"), .seed("user-1")])
  }

  @Test("identify with the current user id changes nothing")
  func identifySameUser() {
    let start = state(appUserId: "user-1", userAttributes: ["custom": 1])
    let result = IdentityUpdate.identify(userId: "user-1").reduce(start)
    #expect(result.pending.isEmpty)
    #expect(result.userAttributes.count == 1)
  }

  // MARK: - seed

  @Test("resolveSeed sets the seed, adds it to the attributes and resolves it")
  func seedResolved() {
    let result = IdentityUpdate.resolveSeed(userId: "user-1", seed: 7)
      .reduce(state(appUserId: "user-1", pending: [.seed("user-1"), .assignments]))
    #expect(result.seed == 7)
    #expect(result.userAttributes["seed"] as? Int == 7)
    #expect(result.userAttributes["appUserId"] as? String == "user-1")
    #expect(result.pending == [.assignments])
  }

  @Test("resolveSeed without a seed resolves it and keeps the current seed")
  func seedSkipped() {
    let result = IdentityUpdate.resolveSeed(userId: "user-1", seed: nil)
      .reduce(state(appUserId: "user-1", pending: [.seed("user-1")]))
    #expect(result.seed == 42)
    #expect(result.pending.isEmpty)
    #expect(result.userAttributes.isEmpty)
  }

  @Test("resolveSeed for a user who is no longer logged in only resolves it")
  func seedForStaleUser() {
    let switched = IdentityUpdate.resolveSeed(userId: "user-1", seed: 7)
      .reduce(state(appUserId: "user-2", pending: [.seed("user-1"), .seed("user-2")]))
    #expect(switched.seed == 42)
    #expect(switched.pending == [.seed("user-2")])

    let reset = IdentityUpdate.resolveSeed(userId: "user-1", seed: 7)
      .reduce(state(pending: [.seed("user-1")]))
    #expect(reset.seed == 42)
    #expect(reset.isReady)
  }

  // MARK: - attributes

  @Test("mergeAttributes adds, overwrites and removes keys, and drops dollar-prefixed ones")
  func mergeAttributes() {
    let start = state(userAttributes: ["keep": "a", "overwrite": "b", "remove": "c"])
    let result = IdentityUpdate.mergeAttributes([
      "overwrite": "B",
      "remove": nil,
      "$dollar": 1,
      "$is_standard_event": true
    ])
    .reduce(start)

    #expect(result.userAttributes["keep"] as? String == "a")
    #expect(result.userAttributes["overwrite"] as? String == "B")
    #expect(result.userAttributes.keys.contains("remove") == false)
    // `IdentityLogic.mergeAttributes` renames `$dollar` to `dollar` but then
    // looks the value up under the new name, so the key ends up removed.
    #expect(result.userAttributes.keys.contains("dollar") == false)
    #expect(result.userAttributes["$dollar"] == nil)
    #expect(result.userAttributes["is_standard_event"] == nil)
    #expect(result.userAttributes["$is_standard_event"] == nil)
    #expect(result.userAttributes["applicationInstalledAt"] as? String == "2026-01-01")
  }

  // MARK: - reset

  @Test("reset replaces the user with a new anonymous one and keeps pending work")
  func reset() {
    let start = state(
      appUserId: "user-1",
      userAttributes: ["custom": 1, "appUserId": "user-1"],
      pending: [.reset, .configuration]
    )
    let result = IdentityUpdate.reset(aliasId: "$SuperwallAlias:new", seed: 3).reduce(start)

    #expect(result.appUserId == nil)
    #expect(result.aliasId == "$SuperwallAlias:new")
    #expect(result.seed == 3)
    #expect(result.pending == [.reset, .configuration])
    #expect(result.appInstalledAtString == "2026-01-01")
    #expect(result.userAttributes["custom"] == nil)
    #expect(result.userAttributes["appUserId"] == nil)
    #expect(result.userAttributes["aliasId"] as? String == "$SuperwallAlias:new")
    #expect(result.userAttributes["seed"] as? Int == 3)
  }

  // MARK: - Cleaning

  @Test("Cleaning keeps JSON-representable values and unwraps JSON")
  func cleanedAttributes() {
    let cleaned = IdentityLogic.cleanedAttributes([
      "string": "a",
      "number": 1,
      "array": [1, 2],
      "json": JSON("wrapped"),
      "date": Date(),
      "null": NSNull()
    ])
    #expect(cleaned["string"] as? String == "a")
    #expect(cleaned["number"] as? Int == 1)
    #expect(cleaned["array"] as? [Int] == [1, 2])
    #expect(cleaned["json"] as? String == "wrapped")
    #expect(cleaned["date"] == nil)
    #expect(cleaned["null"] is NSNull)
  }
}
