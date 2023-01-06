//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/01/2023.
//

import Foundation

extension Date {
  var timeIntervalSinceNowInMilliseconds: Milliseconds {
    return timeIntervalSinceNow * 1000
  }
}
