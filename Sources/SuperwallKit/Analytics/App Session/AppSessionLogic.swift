//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/05/2022.
//

import Foundation

enum AppSessionLogic {
  /// Tells you if the session started depending on when the app was last closed and the specified session timeout.
  ///
  /// - Parameters:
  ///   - lastAppClose: The date when the app was last closed.
  ///   - timeout: The timeout for the session, as defined by the config, in milliseconds.
  static func didStartNewSession(
    _ lastAppClose: Date?,
    withSessionTimeout timeout: Milliseconds?
  ) -> Bool {
    let anHourAgo: Milliseconds = 3600000.0
    let timeout = timeout ?? anHourAgo

    let delta: TimeInterval
    if let lastAppClose = lastAppClose {
      delta = -lastAppClose.timeIntervalSinceNow * 1000
    } else {
      delta = timeout + 1
    }

    return delta > timeout
  }
}
