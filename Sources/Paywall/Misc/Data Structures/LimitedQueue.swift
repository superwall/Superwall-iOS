//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/05/2022.
//

import Foundation

/**
  First-in, first-out queue (FIFO) with a max limit for the number of items in the queue.

  New elements are added to the end of the queue. Dequeuing pulls elements from
  the front of the queue.

  Enqueuing and dequeuing are O(1) operations.
*/
struct LimitedQueue<T> {
  /// The queue that we add our elements to.
  private var array: [T?] = []
  private var head = 0
  private let limit: Int

  init(limit: Int) {
    self.limit = limit
  }

  /**
    Checks if the queue is empty or not.

    - returns: A Bool indicating whether the queue is empty (true) or not (false).
  */
  var isEmpty: Bool {
    // swiftlint:disable:next empty_count
    return count == 0
  }

  /**
    Tells you how many items there are in the queue.

    - returns: The count of the queue
  */
  var count: Int {
    return array.count - head
  }

  /**
    Tells you what is at the front of the queue.

    - returns: The element at the front of the queue
  */
  var front: T? {
    if isEmpty {
      return nil
    } else {
      return array[head]
    }
  }

  /// Returns the array of queued values.
  func getArray() -> [T] {
    let optionalArray = Array(array[head..<array.endIndex])
    return optionalArray.compactMap { $0 }
  }

  /**
  Adds the element to the back of the queue, if within the limit. Otherwise, it dequeues the first element before adding the new element.

  - parameter element: The element to be added to the back of the queue.
  */
  mutating func enqueue(_ element: T) {
    if count < limit {
      array.append(element)
    } else {
      dequeue()
      array.append(element)
    }
  }

  /**
  Removes and returns the element at the front of the queue.

  - returns: The element at the front of the queue.
  */
  @discardableResult
  mutating func dequeue() -> T? {
    guard let element = array[guarded: head] else {
      return nil
    }

    array[head] = nil
    head += 1

    let percentage = Double(head) / Double(array.count)
    if array.count > 50 && percentage > 0.25 {
      array.removeFirst(head)
      head = 0
    }

    return element
  }

  /// Clears the queue.
  mutating func clear() {
    array.removeAll()
    head = 0
  }
}
