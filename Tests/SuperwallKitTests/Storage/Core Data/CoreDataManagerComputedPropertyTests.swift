//
//  CoreDataManagerComputedPropertyTests.swift
//  SuperwallKitTests
//

import Foundation
import Testing
@testable import SuperwallKit

struct CoreDataManagerComputedPropertyTests {
  private let coreDataManager = CoreDataManager(coreDataStack: CoreDataStackMock())

  private func save(_ name: String, secondsAgo: TimeInterval) async -> PlacementData {
    let placementData = PlacementData.stub()
      .setting(\.name, to: name)
      .setting(\.createdAt, to: Date().addingTimeInterval(-secondsAgo))
    await withCheckedContinuation { continuation in
      coreDataManager.savePlacementData(placementData) { _ in
        continuation.resume()
      }
    }
    return placementData
  }

  private func hoursSince(
    _ name: String,
    after placement: PlacementData? = nil
  ) async -> Int? {
    return await coreDataManager.getComputedPropertySincePlacement(
      placement,
      request: ComputedPropertyRequest(type: .hoursSince, placementName: name)
    )
  }

  @Test func noSavedPlacement_returnsNil() async {
    #expect(await hoursSince("missing") == nil)
  }

  @Test func savedPlacement_returnsTimeSinceIt() async {
    _ = await save("opened", secondsAgo: 3 * 3600 + 60)

    #expect(await hoursSince("opened") == 3)
  }

  @Test func usesTheMostRecentPlacement() async {
    _ = await save("opened", secondsAgo: 8 * 3600 + 60)
    _ = await save("opened", secondsAgo: 2 * 3600 + 60)

    #expect(await hoursSince("opened") == 2)
  }

  @Test func ignoresOtherPlacementNames() async {
    _ = await save("opened", secondsAgo: 4 * 3600 + 60)
    _ = await save("closed", secondsAgo: 60)

    #expect(await hoursSince("opened") == 4)
  }

  /// The placement being evaluated has just been saved, so it's skipped and the one
  /// before it is measured instead.
  @Test func samePlacementBeingEvaluated_measuresTheOneBeforeIt() async {
    _ = await save("opened", secondsAgo: 5 * 3600 + 60)
    let current = await save("opened", secondsAgo: 0)

    #expect(await hoursSince("opened", after: current) == 5)
  }

  @Test func differentPlacementBeingEvaluated_measuresTheLatest() async {
    _ = await save("opened", secondsAgo: 6 * 3600 + 60)
    let current = await save("closed", secondsAgo: 0)

    #expect(await hoursSince("opened", after: current) == 6)
  }

  @Test func onlyPlacementIsTheOneBeingEvaluated_returnsNil() async {
    let current = await save("opened", secondsAgo: 0)

    #expect(await hoursSince("opened", after: current) == nil)
  }
}
