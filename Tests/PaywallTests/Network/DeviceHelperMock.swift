//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/08/2022.
//

import Foundation
@testable import Paywall

final class DeviceHelperMock: DeviceHelper {
  var internalLocale: String?
  var internalMinutesSinceInstall: Int = 0

  override var locale: String {
    return internalLocale ?? super.locale
  }

  override var minutesSinceInstall: Int {
    return internalMinutesSinceInstall
  }
}
