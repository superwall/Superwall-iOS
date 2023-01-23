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

  override var locale: String {
    return internalLocale ?? super.locale
  }
}
