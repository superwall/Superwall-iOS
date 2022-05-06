//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/05/2022.
//

import Foundation

enum AppSessionLogic {
  /// Session started if app was closed more than 2 mins ago.
  static func sessionDidStart(
    _ lastAppClose: Date?
  ) -> Bool {
    let twoMinsAgo = 120.0

    let delta: TimeInterval
    if let lastAppClose = lastAppClose {
      delta = -lastAppClose.timeIntervalSinceNow
    } else {
      delta = twoMinsAgo + 1
    }

    return delta > twoMinsAgo
  }
}
