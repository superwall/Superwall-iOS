//
//  UIViewController+TopVc.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import UIKit

extension UIViewController {
  static var topMostViewController: UIViewController? {
    let sharedApplication = UIApplication.shared
    var topViewController: UIViewController? = sharedApplication.activeWindow?.rootViewController
    while let presentedViewController = topViewController?.presentedViewController {
      topViewController = presentedViewController
    }
    return topViewController
  }
}
