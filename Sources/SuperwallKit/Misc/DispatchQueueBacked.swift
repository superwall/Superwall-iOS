//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/08/2023.
//

import Foundation

/// A property wrapper that synchronizes access to its value with
/// a `DispatchQueue`.
@propertyWrapper
public final class DispatchQueueBacked<T>: @unchecked Sendable {
  private var value: T
  private let queue: DispatchQueue

  public init(wrappedValue: T) {
    self.value = wrappedValue
    self.queue = DispatchQueue(label: "com.superwall.\(UUID().uuidString)")
  }

  public var wrappedValue: T {
    get {
      queue.sync {
        value
      }
    }
    set {
      queue.async { [weak self] in
        self?.value = newValue
      }
    }
  }
}
