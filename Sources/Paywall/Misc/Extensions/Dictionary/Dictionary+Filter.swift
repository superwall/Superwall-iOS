//
//  Dictionary+Filter.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import UIKit

extension Dictionary {
  func removingNSNullValues() -> Dictionary {
    self.filter { !($0.value is NSNull) }
  }
}
