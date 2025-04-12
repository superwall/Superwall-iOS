//
//  TaskRetryingTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 10/04/2025.
//

import Testing
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
}
