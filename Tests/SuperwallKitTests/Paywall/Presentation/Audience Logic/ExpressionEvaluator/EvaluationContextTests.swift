//
//  EvaluationContextTests.swift
//  SuperwallKit
//
//  Created by Adedeji Toki on 18/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct EvaluationContextTests {
  private static var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
  }

  private static func minutes(days: Int) -> Int {
    days * 24 * 60
  }

  @Test(arguments: [
    // March 15 back to February 15: 28 days.
    (date(2026, 3, 15), 28),
    // August 15 back to July 15: 31 days.
    (date(2026, 8, 15), 31),
    // May 15 back to April 15: 30 days.
    (date(2026, 5, 15), 30),
    // March 31 back to February 28: February has no 31st, so 31 days.
    (date(2026, 3, 31), 31)
  ])
  func placementsInMonth_coversOneCalendarMonth(now: Date, expectedDays: Int) {
    let interval = EvaluationContext.placementCountInterval(
      for: .placementsInMonth,
      now: now,
      calendar: Self.utcCalendar
    )

    #expect(interval == .minutes(Self.minutes(days: expectedDays)))
  }

  @Test func placementsInMonth_isNotThirtyWeeks() {
    let interval = EvaluationContext.placementCountInterval(for: .placementsInMonth)

    guard case let .minutes(minutes) = interval else {
      Issue.record("Expected a minutes interval, got \(interval)")
      return
    }
    // A calendar month is 28 to 31 days, plus or minus an hour for daylight saving.
    #expect(minutes >= Self.minutes(days: 28) - 60)
    #expect(minutes <= Self.minutes(days: 31) + 60)
  }

  @Test func otherPlacementCounts_keepTheirWindows() {
    let now = Self.date(2026, 3, 15)
    let calendar = Self.utcCalendar

    #expect(
      EvaluationContext.placementCountInterval(for: .placementsInHour, now: now, calendar: calendar)
        == .minutes(60)
    )
    #expect(
      EvaluationContext.placementCountInterval(for: .placementsInDay, now: now, calendar: calendar)
        == .minutes(Self.minutes(days: 1))
    )
    #expect(
      EvaluationContext.placementCountInterval(for: .placementsInWeek, now: now, calendar: calendar)
        == .minutes(Self.minutes(days: 7))
    )
    #expect(
      EvaluationContext.placementCountInterval(
        for: .placementsSinceInstall,
        now: now,
        calendar: calendar
      ) == .infinity
    )
  }

  @Test func placementsInMonth_countsOnlyTheLastMonth() async {
    let coreDataManager = CoreDataManagerMock(coreDataStack: CoreDataStackMock())
    await withCheckedContinuation { continuation in
      coreDataManager.deleteAllEntities {
        continuation.resume()
      }
    }

    let placementName = "article_read"
    let day: TimeInterval = 24 * 60 * 60
    for daysAgo in [1.0, 20, 45, 100] {
      let placementData = PlacementData.stub()
        .setting(\.name, to: placementName)
        .setting(\.createdAt, to: Date().addingTimeInterval(-daysAgo * day))
      await withCheckedContinuation { continuation in
        coreDataManager.savePlacementData(placementData) { _ in
          continuation.resume()
        }
      }
    }

    let count = await coreDataManager.countPlacement(
      placementName,
      interval: EvaluationContext.placementCountInterval(for: .placementsInMonth)
    )

    // Only the events from 1 and 20 days ago fall within the last month.
    #expect(count == 2)
  }
}
