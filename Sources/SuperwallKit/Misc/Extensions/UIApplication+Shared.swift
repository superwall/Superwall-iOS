//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 16/06/2025.
//

#if !os(macOS)
import UIKit

extension UIApplication {
  /// Uses KVC to get the `sharedApplication.
  ///
  /// This is because `UIApplication.shared` isn't available in extensions.
  static var sharedApplication: UIApplication? {
    return UIApplication.value(forKey: "sharedApplication") as? UIApplication
  }
}
#endif
