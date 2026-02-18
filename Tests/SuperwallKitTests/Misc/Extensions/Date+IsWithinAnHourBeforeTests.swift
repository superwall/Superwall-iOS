//
//  File.swift
//
//
//  Created by Yusuf Tör on 19/09/2023.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

struct Date_WithinAnHourBeforeTests {
  @Test func isWithinAnHourBefore_twoHoursAgo() {
    let now = Date()
    let oneHourBefore = now.addingTimeInterval(-7200)
    let result = oneHourBefore.isWithinAnHourBefore(now)
    #expect(!result)
  }

  @Test func isWithinAnHourBefore_oneHourAgo() {
    let now = Date()
    let oneHourBefore = now.addingTimeInterval(-3600)
    let result = oneHourBefore.isWithinAnHourBefore(now)
    #expect(!result)
  }

  @Test func isWithinAnHourBefore_59minsAgo() {
    let now = Date()
    let oneHourBefore = now.addingTimeInterval(-3599)
    let result = oneHourBefore.isWithinAnHourBefore(now)
    #expect(result)
  }

  @Test func isWithinAnHourBefore_exactSame() {
    let now = Date()
    let oneHourBefore = now
    let result = oneHourBefore.isWithinAnHourBefore(now)
    #expect(result)
  }

  @Test func isWithinAnHourBefore_inFuture() {
    let now = Date()
    let oneHourBefore = now.addingTimeInterval(60)
    let result = oneHourBefore.isWithinAnHourBefore(now)
    #expect(result)
  }
}
