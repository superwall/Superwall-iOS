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
  ///   - timeout: The timeout for the session, as defined by the config, in milliseconds. By default, this value is 1 hour.
  static func didStartNewSession(
    _ lastAppClose: Date?,
    withSessionTimeout timeout: Milliseconds?
  ) -> Bool {
    // Set the timeout value as provided, or with a default of 1 hour.
    let timeout = timeout ?? 3600000.0

    // If the app has never been closed, we've started a new session.
    guard let lastAppClose = lastAppClose else {
      return true
    }

    // Determine the elapsed duration between now and the last app close (in milliseconds).
    let elapsedDuration = -lastAppClose.timeIntervalSinceNowInMilliseconds

    // If it's been longer than the provided session timeout duration, we should consider this the start of a new session.
    return elapsedDuration > timeout
  }
}

extension Date {
  var timeIntervalSinceNowInMilliseconds: Milliseconds {
    return timeIntervalSinceNow * 1000
  }
}
