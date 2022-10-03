//
//  UIWindow+Landscape.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import UIKit

extension UIWindow {
  static var isLandscape: Bool {
    return UIApplication.shared.windows
      .first?
      .windowScene?
      .interfaceOrientation
      .isLandscape ?? false
  }
}
