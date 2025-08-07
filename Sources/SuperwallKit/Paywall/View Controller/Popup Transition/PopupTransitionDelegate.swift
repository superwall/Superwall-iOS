//
//  PopupTransitionDelegate.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 06/08/2025.
//

import UIKit

final class PopupTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return PopupTransition(state: .presenting)
  }

  func animationController(
    forDismissed dismissed: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return PopupTransition(state: .dismissing)
  }
}