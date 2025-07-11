//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/08/2022.
//

import Foundation
@testable import SuperwallKit

final class DeviceHelperMock: DeviceHelper {
  var internalLocale: String?

  override var localeIdentifier: String {
    return internalLocale ?? super.localeIdentifier
  }
}
