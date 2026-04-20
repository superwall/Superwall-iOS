//
//  PopupTransitionTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 06/08/2025.
//

import Testing
import UIKit
@testable import SuperwallKit

@MainActor
struct PopupTransitionTests {

  @Test
  func popupTransitionDelegate_presentingAnimator() {
    let delegate = PopupTransitionDelegate()

    let presentedVC = UIViewController()
    let presentingVC = UIViewController()
    let sourceVC = UIViewController()

    let animator = delegate.animationController(
      forPresented: presentedVC,
      presenting: presentingVC,
      source: sourceVC
    )

    #expect(animator != nil)
    #expect(animator is PopupTransition)

    if let popupTransition = animator as? PopupTransition {
      #expect(popupTransition.state == .presenting)
    }
  }

  @Test
  func popupTransitionDelegate_dismissingAnimator() {
    let delegate = PopupTransitionDelegate()

    let dismissedVC = UIViewController()

    let animator = delegate.animationController(forDismissed: dismissedVC)

    #expect(animator != nil)
    #expect(animator is PopupTransition)

    if let popupTransition = animator as? PopupTransition {
      #expect(popupTransition.state == .dismissing)
    }
  }

  @Test
  func popupTransition_presentingDuration() {
    let transition = PopupTransition(state: .presenting)
    let duration = transition.transitionDuration(using: nil)

    #expect(duration == 0.3)
  }

  @Test
  func popupTransition_dismissingDuration() {
    let transition = PopupTransition(state: .dismissing)
    let duration = transition.transitionDuration(using: nil)

    #expect(duration == 0.25)
  }
}
