//
//  UIWindow+Landscape.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import UIKit

extension UIWindow {
  static var isLandscape: Bool {
    guard let sharedApplication = UIApplication.sharedApplication else {
      return false
    }
    return sharedApplication.windows
      .first?
      .windowScene?
      .interfaceOrientation
      .isLandscape ?? false
  }
}
