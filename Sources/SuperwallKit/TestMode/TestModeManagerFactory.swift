//
//  TestModeManagerFactory.swift
//  Superwall
//
//  Created by Jordan Morgan on 2026-01-27.
//

import Foundation

protocol TestModeManagerFactory {
  func makeTestModeManager() -> TestModeManager
}
