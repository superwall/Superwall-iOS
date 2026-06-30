//
//  SK2StoreProductCyclesTests.swift
//  SuperwallKitTests
//
//  Tests for `SK2StoreProduct.cyclesInCommitment` — how many billing cycles
//  fit into a commitment period across the billing/commitment unit pairs Apple
//  can return.
//

@testable import SuperwallKit
import StoreKit
import Testing

// swiftlint:disable all

struct SK2StoreProductCyclesTests {
  // `@available` can't go on the struct/tests (Swift Testing's `@Test` macro
  // rejects availability-annotated functions), so it lives on this helper and
  // each test guards with `#available` before calling it.
  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  private func cycles(
    _ billingUnit: StoreKit.Product.SubscriptionPeriod.Unit,
    _ billingValue: Int,
    inCommitment commitmentUnit: StoreKit.Product.SubscriptionPeriod.Unit,
    _ commitmentValue: Int
  ) -> Int {
    SK2StoreProduct.cyclesInCommitment(
      billingUnit: billingUnit,
      billingValue: billingValue,
      commitmentUnit: commitmentUnit,
      commitmentValue: commitmentValue
    )
  }

  // MARK: - Month/year commitments (exact via ×12)

  @Test
  func monthlyOnYearly_is12() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.month, 1, inCommitment: .year, 1) == 12)
  }

  @Test
  func biMonthlyOnYearly_is6() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.month, 2, inCommitment: .year, 1) == 6)
  }

  @Test
  func quarterlyOnYearly_is4() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.month, 3, inCommitment: .year, 1) == 4)
  }

  @Test
  func sixMonthOnYearly_is2() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.month, 6, inCommitment: .year, 1) == 2)
  }

  @Test
  func monthlyOnSixMonthCommitment_is6() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.month, 1, inCommitment: .month, 6) == 6)
  }

  @Test
  func biMonthlyOnSixMonthCommitment_is3() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.month, 2, inCommitment: .month, 6) == 3)
  }

  @Test
  func yearlyOnTwoYearCommitment_is2() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.year, 1, inCommitment: .year, 2) == 2)
  }

  // MARK: - Day/week commitments (exact via ×7)

  @Test
  func dailyOnWeeklyCommitment_is7() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.day, 1, inCommitment: .week, 1) == 7)
  }

  @Test
  func weeklyOnFourWeekCommitment_is4() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.week, 1, inCommitment: .week, 4) == 4)
  }

  // MARK: - Up-front (billing period == commitment period → 1)

  @Test
  func yearlyUpFront_is1() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.year, 1, inCommitment: .year, 1) == 1)
  }

  @Test
  func monthlyUpFront_is1() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.month, 1, inCommitment: .month, 1) == 1)
  }

  // MARK: - Cross-family (no exact conversion → day approximation)

  @Test
  func fourWeeklyOnYearly_approximatesTo13() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    // week (day-family) vs year (month-family): 365 / 28 ≈ 13.04 → 13.
    #expect(cycles(.week, 4, inCommitment: .year, 1) == 13)
  }

  @Test
  func weeklyOnYearly_approximatesTo52() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    // 365 / 7 ≈ 52.14 → 52.
    #expect(cycles(.week, 1, inCommitment: .year, 1) == 52)
  }

  @Test
  func dailyOnMonthly_approximatesTo30() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    // 30 / 1 = 30 (month approximated as 30 days).
    #expect(cycles(.day, 1, inCommitment: .month, 1) == 30)
  }

  // MARK: - Degenerate input

  @Test
  func zeroBillingValue_defaultsTo1() {
    guard #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) else { return }
    #expect(cycles(.month, 0, inCommitment: .year, 1) == 1)
  }
}
