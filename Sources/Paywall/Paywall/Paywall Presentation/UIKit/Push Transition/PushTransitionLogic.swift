//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/06/2022.
//

import UIKit

enum PushTransitionLogic {
  static func interruptibleAnimator(
    forState state: TransitionState,
    duration: TimeInterval,
    animator: UIViewImplicitlyAnimating?,
    using transitionContext: UIViewControllerContextTransitioning
  ) -> UIViewImplicitlyAnimating? {
    if let animator = animator {
      return animator
    }

    guard
      let fromVC = transitionContext.viewController(forKey: .from),
      let fromView = fromVC.view,
      let toView = transitionContext.viewController(forKey: .to)?.view
    else {
      return nil
    }

    switch state {
    case .presenting:
      return presentingAnimator(
        fromVC: fromVC,
        fromView: fromView,
        toView: toView,
        duration: duration,
        using: transitionContext
      )
    case .dismissing:
      return dismissingAnimator(
        fromVC: fromVC,
        fromView: fromView,
        toView: toView,
        duration: duration,
        using: transitionContext
      )
    }
  }

  private static func presentingAnimator(
    fromVC: UIViewController,
    fromView: UIView,
    toView: UIView,
    duration: TimeInterval,
    using transitionContext: UIViewControllerContextTransitioning
  ) -> UIViewImplicitlyAnimating? {
    let container = transitionContext.containerView

    let fromViewInitialFrame = transitionContext.initialFrame(for: fromVC)

    var fromViewFinalFrame = fromViewInitialFrame
    fromViewFinalFrame.origin.x = -fromViewFinalFrame.width / 3

    var toViewInitialFrame = fromViewInitialFrame
    toViewInitialFrame.origin.x = toView.frame.size.width

    toView.frame = toViewInitialFrame
    container.addSubview(toView)

    let animator = UIViewPropertyAnimator(
      duration: duration,
      controlPoint1: CGPoint(x: 0.28, y: 0.28),
      controlPoint2: CGPoint(x: 0.0, y: 1.0)
    ) {
      toView.frame = fromViewInitialFrame
      fromView.frame = fromViewFinalFrame
    }

    animator.addCompletion { _ in
      transitionContext.completeTransition(true)
    }

    return animator
  }

  private static func dismissingAnimator(
    fromVC: UIViewController,
    fromView: UIView,
    toView: UIView,
    duration: TimeInterval,
    using transitionContext: UIViewControllerContextTransitioning
  ) -> UIViewImplicitlyAnimating? {
    var fromViewInitialFrame = transitionContext.initialFrame(for: fromVC)
    fromViewInitialFrame.origin.x = 0

    var fromViewFinalFrame = fromViewInitialFrame
    fromViewFinalFrame.origin.x = fromViewFinalFrame.width

    var toViewInitialFrame = fromViewInitialFrame
    toViewInitialFrame.origin.x = -toView.frame.size.width / 3

    toView.frame = toViewInitialFrame

    let animator = UIViewPropertyAnimator(
      duration: duration,
      controlPoint1: CGPoint(x: 0.12, y: 0.12),
      controlPoint2: CGPoint(x: 0.22, y: 1.0)
    ) {
      toView.frame = fromViewInitialFrame
      fromView.frame = fromViewFinalFrame
    }

    animator.addCompletion { _ in
      transitionContext.completeTransition(true)
    }

    return animator
  }
}
