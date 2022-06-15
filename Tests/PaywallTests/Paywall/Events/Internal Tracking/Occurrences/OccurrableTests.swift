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
  func test_sinceInstall_inPostfix() {
    // Given
    let type = Occurrence.SinceInstall.self
    let eventArray: [EventData] = [.stub(), .stub()]

    // When
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: false
    )

    XCTAssertEqual(occurrences, 3)
  }

  func test_sinceInstall_notInPostfix() {
    // Given
    let type = Occurrence.SinceInstall.self
    let eventArray: [EventData] = [.stub(), .stub()]

    // When
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: true
    )

    XCTAssertEqual(occurrences, 2)
  }

  func test_last30Days_inPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: false
    )

    XCTAssertEqual(occurrences, 4)
  }

  func test_last30Days_notInPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: true
    )

    XCTAssertEqual(occurrences, 3)
  }

  func test_last7Days_inPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: false
    )

    XCTAssertEqual(occurrences, 3)
  }

  func test_last7Days_notInPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: true
    )

    XCTAssertEqual(occurrences, 2)
  }

  func test_last24Hours_inPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: false
    )

    XCTAssertEqual(occurrences, 2)
  }

  func test_last24Hours_notInPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: true
    )

    XCTAssertEqual(occurrences, 1)
  }

  func test_latestSession_inPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: false
    )

    XCTAssertEqual(occurrences, 2)
  }

  func test_latestSession_notInPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: true
    )

    XCTAssertEqual(occurrences, 1)
  }

  func test_today_inPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: false
    )

    XCTAssertEqual(occurrences, 2)
  }

  func test_today_notInPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: true
    )

    XCTAssertEqual(occurrences, 1)
  }

  func test_firstTime_inPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: false
    )

    XCTAssertEqual(occurrences, oneMinuteAhead.isoString)
  }

  func test_firstTime_notInPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: true
    )

    XCTAssertEqual(occurrences, oneMinuteAhead.isoString)
  }

  func test_lastTime_inPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: false
    )

    XCTAssertGreaterThan(occurrences, Date().advanced(by: -50).isoString)
  }

  func test_lastTime_notInPostfix() {
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
    let occurrences = type.getOccurrence(
      from: eventArray,
      isInPostfix: true
    )

    XCTAssertEqual(occurrences, oneMinuteBehind.isoString)
  }
}
