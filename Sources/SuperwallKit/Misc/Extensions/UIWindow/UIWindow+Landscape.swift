//
//  UIWindow+Landscape.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

#if canImport(WebKit)
#if !os(macOS)
import UIKit

extension UIWindow {
  static var isLandscape: Bool {
    return UIApplication.sharedApplication?.activeWindowScene?.interfaceOrientation.isLandscape ?? false
  }
}
#endif
#endif
