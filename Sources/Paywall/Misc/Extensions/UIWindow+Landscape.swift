//
//  UIWindow+Landscape.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import UIKit

extension UIWindow {
  static var isLandscape: Bool {
    if #available(iOS 13.0, *) {
      return UIApplication.shared.windows
        .first?
        .windowScene?
        .interfaceOrientation
        .isLandscape ?? false
    } else {
      return UIApplication.shared.statusBarOrientation.isLandscape
    }
  }
}
