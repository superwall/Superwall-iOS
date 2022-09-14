//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/09/2022.
//

import Foundation

extension Array {
  /// Removes elements at index, if it exists
  mutating func remove(safeAt index: Index) {
    guard index >= 0 && index < endIndex else {
      return
    }
    remove(at: index)
  }
}
