//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/05/2022.
//

import Foundation

extension Array {
  /// Makes sure that the element is within the bounds of the array: O(1)
  subscript(guarded idx: Int) -> Element? {
    guard (startIndex..<endIndex).contains(idx) else {
      return nil
    }
    return self[idx]
  }
}
