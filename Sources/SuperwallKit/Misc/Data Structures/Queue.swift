//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/09/2023.
//
// https://github.com/kodecocodes/swift-algorithm-club/blob/master/Queue/README.markdown#a-more-efficient-queue

import Foundation

/**
  First-in first-out queue (FIFO)

  Note: This isn't threadsafe.
  New elements are added to the end of the queue. Dequeuing pulls elements from
  the front of the queue.

  Enqueuing and dequeuing are O(1) operations.
*/
struct Queue<T> {
  private var array: [T?] = []
  private var head = 0

  var isEmpty: Bool {
    // swiftlint:disable:next empty_count
    return count == 0
  }

  var count: Int {
    return array.count - head
  }

  mutating func enqueue(_ element: T) {
    array.append(element)
  }

  mutating func dequeue() -> T? {
    // Get element at head of queue
    guard let element = array[guarded: head] else {
      return nil
    }

    // Replace the element with nil and increment the head
    array[head] = nil
    head += 1

    // Calculate the percentage of the array that is nil
    let percentage = Double(head) / Double(array.count)

    // If more than 25% of the queue is nil, chop off the head and reset
    // head to 0
    if array.count > 50 && percentage > 0.25 {
      array.removeFirst(head)
      head = 0
    }

    return element
  }

  var front: T? {
    if isEmpty {
      return nil
    } else {
      return array[head]
    }
  }
}
