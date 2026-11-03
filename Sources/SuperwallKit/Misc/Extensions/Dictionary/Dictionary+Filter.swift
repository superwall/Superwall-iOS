//
//  Dictionary+Filter.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Dictionary {
  func removingNSNullValues() -> Dictionary {
    self.filter { !($0.value is NSNull) }
  }
}
