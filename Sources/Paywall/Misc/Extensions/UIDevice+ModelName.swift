//
//  UIDevice+ModelName.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import UIKit

extension UIDevice {
  static var modelName: String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    return machineMirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
  }
}
