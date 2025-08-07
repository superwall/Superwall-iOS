//
//  PopupTransition.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 06/08/2025.
//

import UIKit

final class PopupTransition: NSObject, UIViewControllerAnimatedTransitioning {
  let state: TransitionState
  var animator: UIViewImplicitlyAnimating?

  init(state: TransitionState) {
    self.state = state
    super.init()
  }

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    switch state {
    case .presenting:
      return 0.3
    case .dismissing:
      return 0.25
    }
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    guard let animator = PopupTransitionLogic.interruptibleAnimator(
      forState: state,
      duration: transitionDuration(using: transitionContext),
      animator: animator,
      using: transitionContext
    ) else {
      return
    }
    self.animator = animator
    animator.startAnimation()
  }

  func animationEnded(_ transitionCompleted: Bool) {
    animator = nil
  }
}
