//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/06/2022.
//

import UIKit

enum TransitionState {
  case presenting
  case dismissing
}

final class PushTransition: NSObject, UIViewControllerAnimatedTransitioning {
  var state: TransitionState
  var animator: UIViewImplicitlyAnimating?

  init(state: TransitionState) {
    self.state = state
    super.init()
  }

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    switch state {
    case .presenting:
      return 0.35
    case .dismissing:
      return 0.2
    }
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    guard let animator = PushTransitionLogic.interruptibleAnimator(
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
