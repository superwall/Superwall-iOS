//
//  EvaluationContextTests.swift
//  SuperwallKit
//
//  Created by Adedeji Toki on 18/11/2026.
//
// swiftlint:disable all

import Foundation
import Superscript
import Testing
@testable import SuperwallKit

struct EvaluationContextTests {
  private static let hour: TimeInterval = 60 * 60
  private static let day: TimeInterval = 24 * hour

  private static func calendar(timeZone: String = "UTC") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZone)!
    return calendar
  }

  /// Midday on the given day.
  private static func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    timeZone: String = "UTC"
  ) -> Date {
    calendar(timeZone: timeZone).date(
      from: DateComponents(year: year, month: month, day: day, hour: 12)
    )!
  }

  @Test(arguments: [
    // February has 28 days.
    (date(2026, 3, 15), date(2026, 2, 15)),
    // July has 31 days.
    (date(2026, 8, 15), date(2026, 7, 15)),
    // April has 30 days.
    (date(2026, 5, 15), date(2026, 4, 15)),
    // February has no 31st, so it's pinned to its last day.
    (date(2026, 3, 31), date(2026, 2, 28)),
    // In a leap year that last day is the 29th.
    (date(2028, 3, 31), date(2028, 2, 29)),
    // January goes back to December of the year before.
    (date(2027, 1, 15), date(2026, 12, 15))
  ])
  func placementsInMonth_startsOneCalendarMonthBack(now: Date, expectedStart: Date) {
    let window = EvaluationContext.placementCountWindow(
      for: .placementsInMonth,
      now: now,
      calendar: Self.calendar()
    )

    #expect(window == .since(expectedStart))
  }

  @Test func placementsInMonth_keepsTheTimeOfDayAcrossDaylightSaving() {
    // The clocks in New York went forward an hour on March 8.
    let timeZone = "America/New_York"
    let now = Self.date(2026, 3, 20, timeZone: timeZone)
    let expectedStart = Self.date(2026, 2, 20, timeZone: timeZone)

    let window = EvaluationContext.placementCountWindow(
      for: .placementsInMonth,
      now: now,
      calendar: Self.calendar(timeZone: timeZone)
    )

    #expect(window == .since(expectedStart))
    #expect(now.timeIntervalSince(expectedStart) == 28 * Self.day - Self.hour)
  }

  @Test func placementsInMonth_isAMonthLongByDefault() {
    let now = Date()
    let window = EvaluationContext.placementCountWindow(for: .placementsInMonth, now: now)

    guard case let .since(start) = window else {
      Issue.record("Expected a start date, got \(String(describing: window))")
      return
    }
    // A calendar month is 28 to 31 days, give or take an hour for daylight saving.
    let length = now.timeIntervalSince(start)
    #expect(length >= 28 * Self.day - Self.hour)
    #expect(length <= 31 * Self.day + Self.hour)
  }

  @Test func otherPlacementCounts_keepTheirWindows() {
    let now = Self.date(2026, 3, 15)

    #expect(
      EvaluationContext.placementCountWindow(for: .placementsInHour, now: now)
        == .since(now.addingTimeInterval(-Self.hour))
    )
    #expect(
      EvaluationContext.placementCountWindow(for: .placementsInDay, now: now)
        == .since(now.addingTimeInterval(-Self.day))
    )
    #expect(
      EvaluationContext.placementCountWindow(for: .placementsInWeek, now: now)
        == .since(now.addingTimeInterval(-7 * Self.day))
    )
    #expect(
      EvaluationContext.placementCountWindow(for: .placementsSinceInstall, now: now) == .allTime
    )
  }

  @Test(arguments: [
    ComputedPropertyRequestType.minutesSince,
    .hoursSince,
    .daysSince,
    .monthsSince,
    .yearsSince
  ])
  func timeSincePlacement_hasNoCountWindow(type: ComputedPropertyRequestType) {
    #expect(EvaluationContext.placementCountWindow(for: type) == nil)
  }

  @Test(arguments: [
    // The longest month is 31 days, so 32 days ago is always outside it and
    // 27 days ago always inside.
    ("placementsInMonth", 2),
    ("placementsInWeek", 1),
    ("placementsSinceInstall", 4)
  ])
  func computedProperty_countsThePlacementsInTheWindow(
    property: String,
    expectedCount: Int
  ) async throws {
    let storage = StorageMock()
    let coreDataManager = storage.coreDataManager
    await withCheckedContinuation { continuation in
      coreDataManager.deleteAllEntities {
        continuation.resume()
      }
    }

    let placementName = "article_read"
    for daysAgo in [1.0, 27, 32, 100] {
      let placementData = PlacementData.stub()
        .setting(\.name, to: placementName)
        .setting(\.createdAt, to: Date().addingTimeInterval(-daysAgo * Self.day))
      await withCheckedContinuation { continuation in
        coreDataManager.savePlacementData(placementData) { _ in
          continuation.resume()
        }
      }
    }

    let argsData = try JSONEncoder().encode([PassableValue.string(placementName)])
    let args = try #require(String(data: argsData, encoding: .utf8))
    let context = EvaluationContext(storage: storage, placement: nil)

    let result = await withCheckedContinuation { continuation in
      context.computedProperty(
        name: property,
        args: args,
        callback: ResultCallbackFake { result in
          continuation.resume(returning: result)
        }
      )
    }

    let value = try JSONDecoder().decode(PassableValue.self, from: Data(result.utf8))
    guard case let .int(count) = value else {
      Issue.record("Expected an int, got \(result)")
      return
    }
    #expect(count == expectedCount)
  }

  private static func args(_ placementName: String) throws -> String {
    let data = try JSONEncoder().encode([PassableValue.string(placementName)])
    return try #require(String(data: data, encoding: .utf8))
  }

  @discardableResult
  private static func save(
    _ placementName: String,
    secondsAgo: TimeInterval,
    in storage: Storage
  ) async -> PlacementData {
    let placementData = PlacementData.stub()
      .setting(\.name, to: placementName)
      .setting(\.createdAt, to: Date().addingTimeInterval(-secondsAgo))
    await withCheckedContinuation { continuation in
      storage.coreDataManager.savePlacementData(placementData) { _ in
        continuation.resume()
      }
    }
    return placementData
  }

  private static func hoursSince(
    _ placementName: String,
    whileChecking placement: PlacementData?,
    in storage: Storage
  ) throws -> Int? {
    let context = EvaluationContext(storage: storage, placement: placement)
    let result = context.value(ofProperty: "hoursSince", args: try args(placementName))
    if result.isEmpty {
      return nil
    }
    let value = try JSONDecoder().decode(PassableValue.self, from: Data(result.utf8))
    guard case let .int(hours) = value else {
      Issue.record("Expected an int, got \(result)")
      return nil
    }
    return hours
  }

  /// The evaluator holds its thread until it's answered, so an answer that
  /// arrives after the call has returned came from another thread, and that
  /// thread may never be free to give it.
  @Test(arguments: ["placementsSinceInstall", "placementsInDay", "hoursSince"])
  func property_isAnsweredBeforeTheCallReturns(property: String) async throws {
    let storage = StorageMock()
    await Self.save("article_read", secondsAgo: 3 * Self.hour + 60, in: storage)
    let args = try Self.args("article_read")
    let context = EvaluationContext(storage: storage, placement: nil)

    var deviceAnswer: String?
    context.deviceProperty(
      name: property,
      args: args,
      callback: ResultCallbackFake { deviceAnswer = $0 }
    )
    #expect(deviceAnswer?.isEmpty == false)

    var computedAnswer: String?
    context.computedProperty(
      name: property,
      args: args,
      callback: ResultCallbackFake { computedAnswer = $0 }
    )
    #expect(computedAnswer?.isEmpty == false)
  }

  @Test func timeSincePlacement_isMeasuredFromTheLastOne() async throws {
    let storage = StorageMock()
    await Self.save("article_read", secondsAgo: 8 * Self.hour + 60, in: storage)
    await Self.save("article_read", secondsAgo: 3 * Self.hour + 60, in: storage)

    #expect(try Self.hoursSince("article_read", whileChecking: nil, in: storage) == 3)
  }

  /// The placement being checked is saved before its audience filters are
  /// checked. Measured from itself, the time since it would always be zero.
  @Test func timeSincePlacement_skipsThePlacementBeingChecked() async throws {
    let storage = StorageMock()
    await Self.save("article_read", secondsAgo: 5 * Self.hour + 60, in: storage)
    let current = await Self.save("article_read", secondsAgo: 0, in: storage)

    #expect(try Self.hoursSince("article_read", whileChecking: current, in: storage) == 5)
  }

  @Test func timeSincePlacement_countsTheLatestWhenAnotherPlacementIsBeingChecked() async throws {
    let storage = StorageMock()
    await Self.save("article_read", secondsAgo: 6 * Self.hour + 60, in: storage)
    await Self.save("article_read", secondsAgo: 2 * Self.hour + 60, in: storage)
    let current = await Self.save("article_closed", secondsAgo: 0, in: storage)

    #expect(try Self.hoursSince("article_read", whileChecking: current, in: storage) == 2)
  }

  /// There's no placement before the first one, so it's measured from itself.
  @Test func timeSincePlacement_isZeroTheFirstTimeThePlacementHappens() async throws {
    let storage = StorageMock()
    let current = await Self.save("article_read", secondsAgo: 0, in: storage)

    #expect(try Self.hoursSince("article_read", whileChecking: current, in: storage) == 0)
  }

  @Test func timeSincePlacement_hasNoValueWhenAnotherPlacementNeverHappened() async throws {
    let storage = StorageMock()
    let current = await Self.save("article_closed", secondsAgo: 0, in: storage)

    #expect(try Self.hoursSince("article_read", whileChecking: current, in: storage) == nil)
  }

  /// Counts include the placement being checked, so a limit of "at most twice"
  /// stops the third one.
  @Test func placementCount_includesThePlacementBeingChecked() async throws {
    let storage = StorageMock()
    await Self.save("article_read", secondsAgo: Self.hour, in: storage)
    let current = await Self.save("article_read", secondsAgo: 0, in: storage)
    let context = EvaluationContext(storage: storage, placement: current)

    let result = context.value(
      ofProperty: "placementsSinceInstall",
      args: try Self.args("article_read")
    )

    let value = try JSONDecoder().decode(PassableValue.self, from: Data(result.utf8))
    guard case let .int(count) = value else {
      Issue.record("Expected an int, got \(result)")
      return
    }
    #expect(count == 2)
  }

  @Test func timeSincePlacement_hasNoValueWhenItNeverHappened() throws {
    let context = EvaluationContext(storage: StorageMock(), placement: nil)

    #expect(context.value(ofProperty: "hoursSince", args: try Self.args("article_read")).isEmpty)
  }

  @Test func unknownProperty_hasNoValue() throws {
    let context = EvaluationContext(storage: StorageMock(), placement: nil)

    #expect(context.value(ofProperty: "notAProperty", args: try Self.args("article_read")).isEmpty)
  }

  @Test func propertyWithoutAPlacementName_hasNoValue() {
    let context = EvaluationContext(storage: StorageMock(), placement: nil)

    #expect(context.value(ofProperty: "placementsSinceInstall", args: "[]").isEmpty)
    #expect(context.value(ofProperty: "placementsSinceInstall", args: "[1]").isEmpty)
    #expect(context.value(ofProperty: "placementsSinceInstall", args: "not json").isEmpty)
  }
}

private final class ResultCallbackFake: ResultCallback, @unchecked Sendable {
  private let handler: (String) -> Void

  init(handler: @escaping (String) -> Void) {
    self.handler = handler
    super.init(noPointer: NoPointer())
  }

  required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
    fatalError("Only made by tests")
  }

  override func onResult(result: String) {
    handler(result)
  }
}
