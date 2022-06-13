//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/06/2022.
// swiftlint:disable all

import XCTest
@testable import Paywall

@available(iOS 13.0, *)
final class OccurrableTests: XCTestCase {
  func test_sinceInstall_preemptive() {
    // Given
    let type = Occurrence.SinceInstall.self
    let eventArray: [EventData] = [.stub(), .stub()]

    // When
    let occurrences = type.getOccurrence(
      from: eventArray,
      isPostfix: true
    )

    XCTAssertEqual(occurrences, 3)
  }

  func test_sinceInstall_notPreemptive() {
    // Given
    let type = Occurrence.SinceInstall.self
    let eventArray: [EventData] = [.stub(), .stub()]

    // When
    let occurrences = type.getOccurrence(
      from: eventArray,
      isPostfix: false
    )

    XCTAssertEqual(occurrences, 2)
  }

  func test_last30Days_preemptive() {
    // Given
    let type = Occurrence.Last30Days.self
    let thirtyOneDaysAgo = Date().advanced(by: -31*24*60*60)
    let eightDaysAgo = Date().advanced(by: -8*24*60*60)
    let twentyFiveHoursAgo = Date().advanced(by: -25*60*60)
    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: thirtyOneDaysAgo),
      .stub()
        .setting(\.createdAt, to: eightDaysAgo),
      .stub()
        .setting(\.createdAt, to: twentyFiveHoursAgo),
      .stub()
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: true)

    XCTAssertEqual(occurrences, 4)
  }

  func test_last30Days_notPreemptive() {
    // Given
    let type = Occurrence.Last30Days.self
    let thirtyOneDaysAgo = Date().advanced(by: -31*24*60*60)
    let eightDaysAgo = Date().advanced(by: -8*24*60*60)
    let twentyFiveHoursAgo = Date().advanced(by: -25*60*60)
    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: thirtyOneDaysAgo),
      .stub()
        .setting(\.createdAt, to: eightDaysAgo),
      .stub()
        .setting(\.createdAt, to: twentyFiveHoursAgo),
      .stub()
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: false)

    XCTAssertEqual(occurrences, 3)
  }

  func test_last7Days_preemptive() {
    // Given
    let type = Occurrence.Last7Days.self
    let thirtyOneDaysAgo = Date().advanced(by: -31*24*60*60)
    let eightDaysAgo = Date().advanced(by: -8*24*60*60)
    let twentyFiveHoursAgo = Date().advanced(by: -25*60*60)
    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: thirtyOneDaysAgo),
      .stub()
        .setting(\.createdAt, to: eightDaysAgo),
      .stub()
        .setting(\.createdAt, to: twentyFiveHoursAgo),
      .stub()
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: true)

    XCTAssertEqual(occurrences, 3)
  }

  func test_last7Days_notPreemptive() {
    // Given
    let type = Occurrence.Last7Days.self
    let thirtyOneDaysAgo = Date().advanced(by: -31*24*60*60)
    let eightDaysAgo = Date().advanced(by: -8*24*60*60)
    let twentyFiveHoursAgo = Date().advanced(by: -25*60*60)
    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: thirtyOneDaysAgo),
      .stub()
        .setting(\.createdAt, to: eightDaysAgo),
      .stub()
        .setting(\.createdAt, to: twentyFiveHoursAgo),
      .stub()
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: false)

    XCTAssertEqual(occurrences, 2)
  }

  func test_last24Hours_preemptive() {
    // Given
    let type = Occurrence.Last24Hours.self
    let thirtyOneDaysAgo = Date().advanced(by: -31*24*60*60)
    let eightDaysAgo = Date().advanced(by: -8*24*60*60)
    let twentyFiveHoursAgo = Date().advanced(by: -25*60*60)
    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: thirtyOneDaysAgo),
      .stub()
        .setting(\.createdAt, to: eightDaysAgo),
      .stub()
        .setting(\.createdAt, to: twentyFiveHoursAgo),
      .stub()
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: true)

    XCTAssertEqual(occurrences, 2)
  }

  func test_last24Hours_notPreemptive() {
    // Given
    let type = Occurrence.Last24Hours.self
    let thirtyOneDaysAgo = Date().advanced(by: -31*24*60*60)
    let eightDaysAgo = Date().advanced(by: -8*24*60*60)
    let twentyFiveHoursAgo = Date().advanced(by: -25*60*60)
    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: thirtyOneDaysAgo),
      .stub()
        .setting(\.createdAt, to: eightDaysAgo),
      .stub()
        .setting(\.createdAt, to: twentyFiveHoursAgo),
      .stub()
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: false)

    XCTAssertEqual(occurrences, 1)
  }

  func test_latestSession_preemptive() {
    // Given
    let appSessionStartAt = AppSessionManager.shared.appSession.startAt
    let oneMinuteAhead = appSessionStartAt.advanced(by: 60*60)
    let oneMinuteBehind = appSessionStartAt.advanced(by: -60*60)
    let type = Occurrence.InLatestSession.self

    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: oneMinuteAhead),
      .stub()
        .setting(\.createdAt, to: oneMinuteBehind)
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: true)

    XCTAssertEqual(occurrences, 2)
  }

  func test_latestSession_notPreemptive() {
    // Given
    let appSessionStartAt = AppSessionManager.shared.appSession.startAt
    let oneMinuteAhead = appSessionStartAt.advanced(by: 60*60)
    let oneMinuteBehind = appSessionStartAt.advanced(by: -60*60)
    let type = Occurrence.InLatestSession.self

    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: oneMinuteAhead),
      .stub()
        .setting(\.createdAt, to: oneMinuteBehind)
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: false)

    XCTAssertEqual(occurrences, 1)
  }

  func test_today_preemptive() {
    // Given
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let oneMinuteAhead = startOfDay.advanced(by: 60*60)
    let oneMinuteBehind = startOfDay.advanced(by: -60*60)
    let type = Occurrence.Today.self

    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: oneMinuteAhead),
      .stub()
        .setting(\.createdAt, to: oneMinuteBehind)
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: true)

    XCTAssertEqual(occurrences, 2)
  }

  func test_today_notPreemptive() {
    // Given
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let oneMinuteAhead = startOfDay.advanced(by: 60*60)
    let oneMinuteBehind = startOfDay.advanced(by: -60*60)
    let type = Occurrence.Today.self

    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: oneMinuteAhead),
      .stub()
        .setting(\.createdAt, to: oneMinuteBehind)
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: false)

    XCTAssertEqual(occurrences, 1)
  }

  func test_firstTime_preemptive() {
    // Given
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let oneMinuteAhead = startOfDay.advanced(by: 60*60)
    let oneMinuteBehind = startOfDay.advanced(by: -60*60)
    let type = Occurrence.FirstTime.self

    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: oneMinuteAhead),
      .stub()
        .setting(\.createdAt, to: oneMinuteBehind)
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: true)

    XCTAssertEqual(occurrences, oneMinuteAhead)
  }

  func test_firstTime_notPreemptive() {
    // Given
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let oneMinuteAhead = startOfDay.advanced(by: 60*60)
    let oneMinuteBehind = startOfDay.advanced(by: -60*60)
    let type = Occurrence.FirstTime.self

    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: oneMinuteAhead),
      .stub()
        .setting(\.createdAt, to: oneMinuteBehind)
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: false)

    XCTAssertEqual(occurrences, oneMinuteAhead)
  }

  func test_lastTime_preemptive() {
    // Given
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let oneMinuteAhead = startOfDay.advanced(by: 60*60)
    let oneMinuteBehind = startOfDay.advanced(by: -60*60)
    let type = Occurrence.LastTime.self

    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: oneMinuteAhead),
      .stub()
        .setting(\.createdAt, to: oneMinuteBehind)
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: true)

    XCTAssertGreaterThan(occurrences, Date().advanced(by: -50))
  }

  func test_lastTime_notPreemptive() {
    // Given
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let oneMinuteAhead = startOfDay.advanced(by: 60*60)
    let oneMinuteBehind = startOfDay.advanced(by: -60*60)
    let type = Occurrence.LastTime.self

    let eventArray: [EventData] = [
      .stub()
        .setting(\.createdAt, to: oneMinuteAhead),
      .stub()
        .setting(\.createdAt, to: oneMinuteBehind)
    ]

    // When
    let occurrences = type.getOccurrence(from: eventArray, isPostfix: false)

    XCTAssertEqual(occurrences, oneMinuteBehind)
  }
}
