//
//  Stubbable.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

import Foundation

protocol Stubbable {
  static func stub() -> Self
}

extension Stubbable {
  func setting<T>(
    _ keyPath: WritableKeyPath<Self, T>,
    to value: T) -> Self {
    var stub = self
    stub[keyPath: keyPath] = value
    return stub
  }
}
