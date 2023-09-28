//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/09/2023.
//

import Foundation

/*
  First-in first-out queue (FIFO)

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

  var front: T? {
    if isEmpty {
      return nil
    } else {
      return array[head]
    }
  }
}
