//
//  UIDevice+ModelName.swift
//  Superwall
//
//  Created by Yusuf Tör on 03/03/2022.
//

#if !os(macOS)
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

  /// The model a simulator emulates, such as `iPhone19,4`. `uname` reports the
  /// host's architecture there instead. `nil` on a real device.
  static var simulatorModelName: String? {
    #if targetEnvironment(simulator)
    return simulatorModelName(in: ProcessInfo.processInfo.environment)
    #else
    return nil
    #endif
  }

  static func simulatorModelName(in environment: [String: String]) -> String? {
    guard
      let model = environment["SIMULATOR_MODEL_IDENTIFIER"],
      !model.isEmpty
    else {
      return nil
    }
    return model
  }
}
#endif
