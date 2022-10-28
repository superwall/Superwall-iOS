//
//  TransactionManagerLogicTests.swift
//  
//
//  Created by Yusuf Tör on 30/05/2022.
//
// swiftlint:disable all

import XCTest
import StoreKit
@testable import Superwall

final class TransactionRecorderLogicTests: XCTestCase {
  func testGetTriggerSessionId_purchasing() {
    let id = "abc"
    let transaction = MockSKPaymentTransaction(state: .purchasing)

    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: .stub()
        .setting(\.id, to: id)
    )

    XCTAssertEqual(outcome, id)
  }

  func testGetTriggerSessionId_purchasing_noTriggerSession() {
    let transaction = MockSKPaymentTransaction(state: .purchasing)

    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: nil
    )

    XCTAssertNil(outcome)
  }

  func testGetTriggerSessionId_restored() {
    let id = "abc"
    let transaction = MockSKPaymentTransaction(state: .restored)

    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: .stub()
        .setting(\.id, to: id)
    )

    XCTAssertEqual(outcome, id)
  }

  func testGetTriggerSessionId_restored_noTriggerSession() {
    let transaction = MockSKPaymentTransaction(state: .restored)

    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: nil
    )

    XCTAssertNil(outcome)
  }

  func testGetTriggerSessionId_failed() {
    let id = "abc"
    let transaction = MockSKPaymentTransaction(state: .failed)

    let sessionTransaction = TriggerSession.Transaction(
      startAt: Date(),
      count: nil,
      product: .init(from: MockSkProduct(), index: 0)
    )
    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: .stub()
        .setting(\.id, to: id)
        .setting(\.transaction, to: sessionTransaction)
    )

    XCTAssertEqual(outcome, id)
  }

  func testGetTriggerSessionId_failed_noSessionTransaction() {
    let id = "abc"
    let transaction = MockSKPaymentTransaction(state: .failed)

    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: .stub()
        .setting(\.id, to: id)
        .setting(\.transaction, to: nil)
    )

    XCTAssertNil(outcome)
  }

  func testGetTriggerSessionId_deferred() {
    let id = "abc"
    let transaction = MockSKPaymentTransaction(state: .deferred)

    let sessionTransaction = TriggerSession.Transaction(
      startAt: Date(),
      count: nil,
      product: .init(from: MockSkProduct(), index: 0)
    )
    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: .stub()
        .setting(\.id, to: id)
        .setting(\.transaction, to: sessionTransaction)
    )

    XCTAssertEqual(outcome, id)
  }

  func testGetTriggerSessionId_deferred_noSessionTransaction() {
    let id = "abc"
    let transaction = MockSKPaymentTransaction(state: .deferred)

    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: .stub()
        .setting(\.id, to: id)
        .setting(\.transaction, to: nil)
    )

    XCTAssertNil(outcome)
  }
  
  func testGetTriggerSessionId_purchased() {
    let id = "abc"
    let transaction = MockSKPaymentTransaction(state: .purchased)

    let sessionTransaction = TriggerSession.Transaction(
      startAt: Date(),
      count: nil,
      product: .init(from: MockSkProduct(), index: 0)
    )
    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: .stub()
        .setting(\.id, to: id)
        .setting(\.transaction, to: sessionTransaction)
    )

    XCTAssertEqual(outcome, id)
  }

  func testGetTriggerSessionId_purchased_noSessionTransaction() {
    let id = "abc"
    let transaction = MockSKPaymentTransaction(state: .purchased)

    let outcome = TransactionRecorderLogic.getTriggerSessionId(
      transaction: transaction,
      activeTriggerSession: .stub()
        .setting(\.id, to: id)
        .setting(\.transaction, to: nil)
    )

    XCTAssertNil(outcome)
  }
}
