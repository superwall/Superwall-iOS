//
//  File.swift
//  
//
//  Created by Yusuf Tör on 30/09/2022.
//

import Foundation
@testable import Superwall

final class IdentityManagerMock: IdentityManager {
  var hasConfigured = false

  override func configure() async {
    hasConfigured = true
  }
}
