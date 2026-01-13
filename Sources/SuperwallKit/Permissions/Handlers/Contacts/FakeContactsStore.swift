//
//  FakeContactsStore.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

final class FakeContactStore: NSObject {
  // Class method
  @objc static func authorizationStatusForEntityType(_ entityType: Int) -> Int {
    -1
  }

  // Instance method
  @objc func requestAccessForEntityType(
    _ entityType: Int,
    completionHandler: @escaping (Bool, NSError?) -> Void
  ) {
    completionHandler(false, nil)
  }
}
