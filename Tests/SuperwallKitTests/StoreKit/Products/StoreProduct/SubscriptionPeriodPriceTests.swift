//
//  SubscriptionPeriodPriceTests.swift
//  SuperwallKitTests
//
//  Created by Claude on 2026-01-16.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Tests for SubscriptionPeriod price calculation methods.
/// These methods calculate daily, weekly, monthly, and yearly prices
/// from a total subscription price based on the subscription period.
@Suite("Subscription Period Price Calculations")
struct SubscriptionPeriodPriceTests {

  // MARK: - Daily Price Tests

  @Test("Daily price for yearly subscription")
  func testDailyPriceForYearlySubscription() {
    // $99.99/year should be ~$0.27/day (99.99 / 365)
    let period = SubscriptionPeriod(value: 1, unit: .year)
    let dailyPrice = period.pricePerDay(withTotalPrice: Decimal(99.99))

    // 99.99 / 365 = 0.273... rounds down to 0.27
    #expect(dailyPrice == Decimal(string: "0.27"))
  }

  @Test("Daily price for monthly subscription")
  func testDailyPriceForMonthlySubscription() {
    // $9.99/month should be ~$0.33/day (9.99 / 30)
    let period = SubscriptionPeriod(value: 1, unit: .month)
    let dailyPrice = period.pricePerDay(withTotalPrice: Decimal(9.99))

    // 9.99 / 30 = 0.333 rounds down to 0.33
    #expect(dailyPrice == Decimal(string: "0.33"))
  }

  @Test("Daily price for weekly subscription")
  func testDailyPriceForWeeklySubscription() {
    // $4.99/week should be ~$0.71/day (4.99 / 7)
    let period = SubscriptionPeriod(value: 1, unit: .week)
    let dailyPrice = period.pricePerDay(withTotalPrice: Decimal(4.99))

    // 4.99 / 7 = 0.712... rounds down to 0.71
    #expect(dailyPrice == Decimal(string: "0.71"))
  }

  @Test("Daily price for daily subscription")
  func testDailyPriceForDailySubscription() {
    // $0.99/day should be $0.99/day
    let period = SubscriptionPeriod(value: 1, unit: .day)
    let dailyPrice = period.pricePerDay(withTotalPrice: Decimal(0.99))

    #expect(dailyPrice == Decimal(string: "0.99"))
  }

  @Test("Daily price for multi-month subscription")
  func testDailyPriceForThreeMonthSubscription() {
    // $24.99/3 months should be ~$0.27/day (24.99 / 90)
    let period = SubscriptionPeriod(value: 3, unit: .month)
    let dailyPrice = period.pricePerDay(withTotalPrice: Decimal(24.99))

    // 24.99 / 90 = 0.2776... rounds down to 0.27
    #expect(dailyPrice == Decimal(string: "0.27"))
  }

  // MARK: - Weekly Price Tests

  @Test("Weekly price for yearly subscription")
  func testWeeklyPriceForYearlySubscription() {
    // $99.99/year should be ~$1.92/week (99.99 / 52)
    let period = SubscriptionPeriod(value: 1, unit: .year)
    let weeklyPrice = period.pricePerWeek(withTotalPrice: Decimal(99.99))

    // 99.99 / 52 = 1.923... rounds down to 1.92
    #expect(weeklyPrice == Decimal(string: "1.92"))
  }

  @Test("Weekly price for monthly subscription")
  func testWeeklyPriceForMonthlySubscription() {
    // $9.99/month should be ~$2.49/week (9.99 / 4)
    let period = SubscriptionPeriod(value: 1, unit: .month)
    let weeklyPrice = period.pricePerWeek(withTotalPrice: Decimal(9.99))

    // 9.99 / 4 = 2.4975 rounds down to 2.49
    #expect(weeklyPrice == Decimal(string: "2.49"))
  }

  @Test("Weekly price for weekly subscription")
  func testWeeklyPriceForWeeklySubscription() {
    // $4.99/week should be $4.99/week
    let period = SubscriptionPeriod(value: 1, unit: .week)
    let weeklyPrice = period.pricePerWeek(withTotalPrice: Decimal(4.99))

    #expect(weeklyPrice == Decimal(string: "4.99"))
  }

  // MARK: - Monthly Price Tests

  @Test("Monthly price for yearly subscription")
  func testMonthlyPriceForYearlySubscription() {
    // $99.99/year should be ~$8.33/month (99.99 / 12)
    let period = SubscriptionPeriod(value: 1, unit: .year)
    let monthlyPrice = period.pricePerMonth(withTotalPrice: Decimal(99.99))

    // 99.99 / 12 = 8.3325 rounds down to 8.33
    #expect(monthlyPrice == Decimal(string: "8.33"))
  }

  @Test("Monthly price for monthly subscription")
  func testMonthlyPriceForMonthlySubscription() {
    // $9.99/month should be $9.99/month
    let period = SubscriptionPeriod(value: 1, unit: .month)
    let monthlyPrice = period.pricePerMonth(withTotalPrice: Decimal(9.99))

    #expect(monthlyPrice == Decimal(string: "9.99"))
  }

  @Test("Monthly price for 6-month subscription")
  func testMonthlyPriceForSixMonthSubscription() {
    // $49.99/6 months should be ~$8.33/month (49.99 / 6)
    let period = SubscriptionPeriod(value: 6, unit: .month)
    let monthlyPrice = period.pricePerMonth(withTotalPrice: Decimal(49.99))

    // 49.99 / 6 = 8.331... rounds down to 8.33
    #expect(monthlyPrice == Decimal(string: "8.33"))
  }

  // MARK: - Yearly Price Tests

  @Test("Yearly price for yearly subscription")
  func testYearlyPriceForYearlySubscription() {
    // $99.99/year should be $99.99/year
    let period = SubscriptionPeriod(value: 1, unit: .year)
    let yearlyPrice = period.pricePerYear(withTotalPrice: Decimal(99.99))

    #expect(yearlyPrice == Decimal(string: "99.99"))
  }

  @Test("Yearly price for monthly subscription")
  func testYearlyPriceForMonthlySubscription() {
    // $9.99/month should be ~$119.88/year (9.99 * 12)
    let period = SubscriptionPeriod(value: 1, unit: .month)
    let yearlyPrice = period.pricePerYear(withTotalPrice: Decimal(9.99))

    // 9.99 / (1/12) = 9.99 * 12 = 119.88
    #expect(yearlyPrice == Decimal(string: "119.88"))
  }

  @Test("Yearly price for weekly subscription")
  func testYearlyPriceForWeeklySubscription() {
    // $4.99/week should be ~$259.48/year (4.99 * 52)
    let period = SubscriptionPeriod(value: 1, unit: .week)
    let yearlyPrice = period.pricePerYear(withTotalPrice: Decimal(4.99))

    // 4.99 / (1/52) = 4.99 * 52 = 259.48
    #expect(yearlyPrice == Decimal(string: "259.48"))
  }

  // MARK: - Edge Cases

  @Test("Zero price returns zero")
  func testZeroPriceReturnsZero() {
    let period = SubscriptionPeriod(value: 1, unit: .year)

    #expect(period.pricePerDay(withTotalPrice: Decimal(0)) == Decimal(0))
    #expect(period.pricePerWeek(withTotalPrice: Decimal(0)) == Decimal(0))
    #expect(period.pricePerMonth(withTotalPrice: Decimal(0)) == Decimal(0))
    #expect(period.pricePerYear(withTotalPrice: Decimal(0)) == Decimal(0))
  }

  @Test("Multi-year subscription calculates correctly")
  func testMultiYearSubscription() {
    // $199.99/2 years should be ~$8.33/month (199.99 / 24)
    let period = SubscriptionPeriod(value: 2, unit: .year)
    let monthlyPrice = period.pricePerMonth(withTotalPrice: Decimal(199.99))

    // 199.99 / 24 = 8.332... rounds down to 8.33
    #expect(monthlyPrice == Decimal(string: "8.33"))
  }

  @Test("Large price handles correctly")
  func testLargePriceHandlesCorrectly() {
    // $999.99/year
    let period = SubscriptionPeriod(value: 1, unit: .year)
    let dailyPrice = period.pricePerDay(withTotalPrice: Decimal(999.99))

    // 999.99 / 365 = 2.739... rounds down to 2.73
    #expect(dailyPrice == Decimal(string: "2.73"))
  }

  @Test("Small price rounds down correctly")
  func testSmallPriceRoundsDownCorrectly() {
    // $0.99/year should be ~$0.00/day (rounds down)
    let period = SubscriptionPeriod(value: 1, unit: .year)
    let dailyPrice = period.pricePerDay(withTotalPrice: Decimal(0.99))

    // 0.99 / 365 = 0.00271... rounds down to 0.00
    #expect(dailyPrice == Decimal(string: "0.00"))
  }
}
