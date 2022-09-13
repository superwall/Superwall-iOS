//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/05/2022.
//

import Foundation

extension Array {
  /// Makes sure that the element is within the bounds of the array: O(1)
  subscript(guarded index: Int) -> Element? {
    get {
      guard (startIndex..<endIndex).contains(index) else {
        return nil
      }
      return self[index]
    }
    set(newValue) {
      guard let newValue = newValue else {
        return
      }
      if index >= endIndex {
        append(newValue)
      } else {
        self[index] = newValue
      }
    }
  }

  
}
