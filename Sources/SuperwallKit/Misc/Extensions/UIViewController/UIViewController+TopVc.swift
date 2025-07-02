//
//  UIViewController+TopVc.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import UIKit

extension UIViewController {
  static var topMostViewController: UIViewController? {
    guard let sharedApplication = UIApplication.sharedApplication else {
      return nil
    }
    var topViewController: UIViewController? = sharedApplication.activeWindow?.rootViewController
    while let presentedViewController = topViewController?.presentedViewController {
      topViewController = presentedViewController
    }
    return topViewController
  }
}
