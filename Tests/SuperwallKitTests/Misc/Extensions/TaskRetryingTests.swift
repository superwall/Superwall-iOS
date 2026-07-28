//
//  TaskRetryingTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 10/04/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

struct TaskRetryingTests {
  @Test("Cancels task when timeout is reached")
  func testTaskIsCancelledOnTimeout() async throws {
    let task = Task.retrying(
      maxRetryCount: 3,
      timeout: 1, // 1 second timeout
      isRetryingCallback: nil
    ) {
      // Simulate a long-running operation that should be cancelled
      try await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5 seconds
      return "Finished"
    }

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }

  struct TestFailure: Error {
    let message: String
  }

  @Test("Retries the task up to the maxRetryCount")
  func testRetriesExpectedNumberOfTimes() async throws {
    var attemptCounter = 0

    let task = Task.retrying(
      maxRetryCount: 3,
      retryInterval: 0.01,
      isRetryingCallback: { _ in
        attemptCounter += 1
      }
    ) {
      throw TestFailure(message: "Failing on purpose")
    }

    do {
      _ = try await task.value
      throw TestFailure(message: "Task should not succeed")
    } catch {
      // Expected to throw
    }

    // Expect 3 retries (3 failures)
    #expect(attemptCounter == 3)
  }

  // MARK: - HTTP status handling

  /// Counts how many times the retried operation actually ran.
  private actor CallCounter {
    private(set) var count = 0

    func increment() {
      count += 1
    }
  }

  private static func makeResponse(_ statusCode: Int) -> (Data, URLResponse) {
    let url = URL(string: "https://api.superwall.com/test")!
    let response = HTTPURLResponse(
      url: url,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )!
    return (Data(), response)
  }

  /// Runs `Task.retrying` against a stubbed HTTP status and reports how many times
  /// the operation was invoked.
  private func callCount(forStatusCode statusCode: Int) async -> Int {
    let counter = CallCounter()

    let task = Task.retrying(
      maxRetryCount: 3,
      retryInterval: 0.01,
      isRetryingCallback: nil
    ) {
      await counter.increment()
      return Self.makeResponse(statusCode)
    }

    _ = try? await task.value
    return await counter.count
  }

  @Test(
    "Does not retry terminal client errors",
    arguments: [400, 401, 403, 404, 410, 422]
  )
  func terminalClientErrorsAreNotRetried(statusCode: Int) async {
    #expect(await callCount(forStatusCode: statusCode) == 1)
  }

  @Test(
    "Does not retry redirects that reach the caller",
    arguments: [301, 302, 307, 308]
  )
  func redirectsAreNotRetried(statusCode: Int) async {
    #expect(await callCount(forStatusCode: statusCode) == 1)
  }

  @Test(
    "Retries client errors that may succeed on a retry",
    arguments: [408, 425, 429, 499]
  )
  func retryableClientErrorsAreRetried(statusCode: Int) async {
    // 3 attempts in the retry loop, plus the final unchecked attempt.
    #expect(await callCount(forStatusCode: statusCode) == 4)
  }

  @Test(
    "Retries server errors",
    arguments: [500, 502, 503]
  )
  func serverErrorsAreRetried(statusCode: Int) async {
    #expect(await callCount(forStatusCode: statusCode) == 4)
  }

  @Test("Does not retry a successful response")
  func successIsNotRetried() async {
    #expect(await callCount(forStatusCode: 200) == 1)
  }
}
