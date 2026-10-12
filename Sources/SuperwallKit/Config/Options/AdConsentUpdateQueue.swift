//
//  AdConsentUpdateQueue.swift
//
//
//  Created by Yusuf Tör on 08/10/2026.
//

import Foundation

/// Sends ad consent updates one at a time, in the order they were made, so an older
/// snapshot can never be tracked after a newer one.
///
/// Each ``Superwall/adConsent`` assignment starts a new generation. A job checks
/// that its generation is still current before tracking, so a superseded update is
/// dropped in favour of the newer one queued behind it.
final class AdConsentUpdateQueue: @unchecked Sendable {
  typealias Job = @Sendable () async -> Void

  private let continuation: AsyncStream<Job>.Continuation
  private let lock = NSLock()
  private var generation = 0

  init() {
    let (stream, continuation) = AsyncStream.makeStream(of: Job.self)
    self.continuation = continuation
    Task {
      for await job in stream {
        await job()
      }
    }
  }

  deinit {
    continuation.finish()
  }

  /// The generation of the latest assignment.
  var currentGeneration: Int {
    lock.withLock { generation }
  }

  /// Starts a new generation, making every earlier one stale.
  func nextGeneration() -> Int {
    lock.withLock {
      generation += 1
      return generation
    }
  }

  func isCurrent(_ generation: Int) -> Bool {
    lock.withLock { self.generation == generation }
  }

  /// Runs `job` after every job enqueued before it has finished.
  func enqueue(_ job: @escaping Job) {
    continuation.yield(job)
  }
}
