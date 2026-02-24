//
//  TestModeManagerFactory.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import Foundation

protocol TestModeManagerFactory {
  func makeTestModeManager() -> TestModeManager
}
