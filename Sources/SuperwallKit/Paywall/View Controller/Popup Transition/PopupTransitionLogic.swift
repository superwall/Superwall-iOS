//
//  PopupTransitionLogic.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 06/08/2025.
//

import UIKit

enum PopupTransitionLogic {
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
    guard let toViewController = transitionContext.viewController(forKey: .to) else { return nil }
    let finalFrame = transitionContext.finalFrame(for: toViewController)
    toView.frame = finalFrame

    // iOS alert-style initial state: slightly scaled up and transparent
    toView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
    toView.alpha = 0.0

    container.addSubview(toView)

    // Use iOS-like spring animation
    let animator = UIViewPropertyAnimator(
      duration: duration,
      controlPoint1: CGPoint(x: 0.4, y: 0.0),
      controlPoint2: CGPoint(x: 0.2, y: 1.0)
    ) {
      // Animate to final state with slight overshoot then settle
      toView.transform = .identity
      toView.alpha = 1.0
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
    // Check if this is a PaywallViewController with custom background dismissal
    if let paywallVC = fromVC as? PaywallViewController,
      paywallVC.isCustomBackgroundDismissal {
      // Skip the transition animation - the custom animation is already in progress
      let animator = UIViewPropertyAnimator(duration: 0, curve: .linear) { }
      animator.addCompletion { _ in
        transitionContext.completeTransition(true)
      }
      return animator
    }

    // iOS alert-style dismissal: scale popup content, fade background separately
    let animator = UIViewPropertyAnimator(
      duration: duration,
      controlPoint1: CGPoint(x: 0.4, y: 0.0),
      controlPoint2: CGPoint(x: 1.0, y: 1.0)
    ) {
      // Find the popup container and background views
      if let paywallVC = fromVC as? PaywallViewController,
        let popupContainer = paywallVC.popupContainerView {
        // Scale down only the popup container (foreground content)
        popupContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        popupContainer.alpha = 0.0

        // Find and fade out the background separately
        let backgroundView = fromView.subviews.first { subview in
          subview.backgroundColor == UIColor.black.withAlphaComponent(0.4)
        }
        backgroundView?.alpha = 0.0
      } else {
        // Fallback to scaling the entire view if we can't find the container
        fromView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        fromView.alpha = 0.0
      }
    }

    animator.addCompletion { _ in
      transitionContext.completeTransition(true)
    }

    return animator
  }
}
