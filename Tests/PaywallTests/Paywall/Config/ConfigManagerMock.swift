//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/08/2022.
//
// swiftlint:disable all

import Foundation
@testable import Paywall

final class ConfigManagerMock: ConfigManager {
  var confirmedAssignment = false
  var hasLoadedBlockingAssignments = false
  var hasLoadedNonBlockingAssignments = false

  override func confirmAssignments(
    _ confirmableAssignment: ConfirmableAssignment
  ) {
    confirmedAssignment = true
  }

  override func loadAssignments(completion: (() -> Void)? = nil) {
    super.loadAssignments(completion: completion)
    if completion == nil {
      hasLoadedNonBlockingAssignments = true
    } else {
      hasLoadedBlockingAssignments = true
    }
  }
}
