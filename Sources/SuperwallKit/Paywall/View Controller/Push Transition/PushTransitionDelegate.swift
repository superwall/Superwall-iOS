//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/10/2022.
//

#if !os(macOS)
import UIKit

final class PushTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return PushTransition(state: .presenting)
  }

  func animationController(
    forDismissed dismissed: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    return PushTransition(state: .dismissing)
  }
}
#endif
