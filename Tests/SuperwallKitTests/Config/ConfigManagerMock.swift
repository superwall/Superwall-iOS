//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/08/2022.
//
// swiftlint:disable all

import UIKit
@testable import SuperwallKit

final class ConfigManagerMock: ConfigManager {
  var confirmedAssignment = false

  override func postbackAssignment(_ assignment: Assignment) {
    confirmedAssignment = true
    storage.saveAssignments([assignment])
  }
}
