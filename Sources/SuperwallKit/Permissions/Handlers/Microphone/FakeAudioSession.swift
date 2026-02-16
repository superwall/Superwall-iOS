//
//  FakeAudioSession.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/01/2026.
//

import Foundation

final class FakeAudioSession: NSObject {
  // Class method - returns a shared instance
  @objc static func sharedInstance() -> FakeAudioSession {
    return FakeAudioSession()
  }

  // Instance method - returns -1 to indicate unsupported
  @objc func recordPermission() -> Int {
    return -1
  }

  // Instance method
  @objc func requestRecordPermission(_ completion: @escaping (Bool) -> Void) {
    completion(false)
  }
}
