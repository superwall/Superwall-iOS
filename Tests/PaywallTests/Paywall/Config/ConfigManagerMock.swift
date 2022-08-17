//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/08/2022.
//
// swiftlint:disable all

@testable import Paywall
import XCTest

final class ConfigManagerMock: ConfigManager {
  var confirmedAssignment = false

  override func confirmAssignments(
    _ confirmableAssignment: ConfirmableAssignment,
    network: Network = .shared
  ) {
    confirmedAssignment = true
  }
}
