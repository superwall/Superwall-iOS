//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//

import Foundation

protocol KeyPathWritable {
  func setting<T>(
    _ keyPath: WritableKeyPath<Self, T>,
    to value: T
  ) -> Self
}

extension KeyPathWritable {
  func setting<T>(
    _ keyPath: WritableKeyPath<Self, T>,
    to value: T
  ) -> Self {
    var stub = self
    stub[keyPath: keyPath] = value
    return stub
  }
}
