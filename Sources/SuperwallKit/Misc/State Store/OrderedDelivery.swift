//
//  OrderedDelivery.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

/// Hands values to a receiver one at a time, in the order they were added,
/// without holding a lock while the receiver runs.
///
/// A ``StateStore`` observer runs with the store locked, so anything it calls
/// that takes another lock can deadlock against a thread that holds that lock
/// and reads the store. An observer instead adds the value here, which keeps
/// the order the updates were applied in, and calls ``deliver()`` once the
/// store is unlocked.
///
/// Only one thread delivers at a time. A ``deliver()`` call while another
/// thread is delivering returns straight away, and that thread delivers the
/// value after the ones before it. Called from the receiver, it returns
/// straight away too, and the value is delivered once the receiver returns,
/// unless the delivery was made with `deliversNestedValues`.
final class OrderedDelivery<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var queue: [Value] = []
  private var deliveringThread: Thread?
  private let deliversNestedValues: Bool
  private let receive: (Value) -> Void

  /// - Parameter deliversNestedValues: Whether a ``deliver()`` call from the
  ///   receiver delivers the waiting values before it returns, as a
  ///   property's `didSet` does when its observer sets the property again.
  ///   Calls from other threads still return straight away.
  init(
    deliversNestedValues: Bool = false,
    _ receive: @escaping (Value) -> Void
  ) {
    self.deliversNestedValues = deliversNestedValues
    self.receive = receive
  }

  /// Adds `value` after the values already waiting.
  func add(_ value: Value) {
    lock.lock()
    queue.append(value)
    lock.unlock()
  }

  /// Delivers the waiting values in order, unless another delivery is
  /// already running, which delivers them instead.
  func deliver() {
    lock.lock()
    let isNested = deliveringThread === Thread.current
    if deliveringThread != nil,
      !(isNested && deliversNestedValues) {
      lock.unlock()
      return
    }
    deliveringThread = Thread.current
    while !queue.isEmpty {
      let value = queue.removeFirst()
      lock.unlock()
      receive(value)
      lock.lock()
    }
    if !isNested {
      deliveringThread = nil
    }
    lock.unlock()
  }
}
