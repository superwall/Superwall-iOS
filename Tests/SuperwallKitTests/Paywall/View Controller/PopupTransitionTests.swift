//
//  PopupTransitionTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 06/08/2025.
//

import XCTest
@testable import SuperwallKit

final class PopupTransitionTests: XCTestCase {
  
  func test_popupTransitionDelegate_presentingAnimator() {
    let delegate = PopupTransitionDelegate()
    
    let presentedVC = UIViewController()
    let presentingVC = UIViewController()
    let sourceVC = UIViewController()
    
    let animator = delegate.animationController(
      forPresented: presentedVC,
      presenting: presentingVC,
      source: sourceVC
    )
    
    XCTAssertNotNil(animator)
    XCTAssertTrue(animator is PopupTransition)
    
    if let popupTransition = animator as? PopupTransition {
      XCTAssertEqual(popupTransition.state, .presenting)
    }
  }
  
  func test_popupTransitionDelegate_dismissingAnimator() {
    let delegate = PopupTransitionDelegate()
    
    let dismissedVC = UIViewController()
    
    let animator = delegate.animationController(forDismissed: dismissedVC)
    
    XCTAssertNotNil(animator)
    XCTAssertTrue(animator is PopupTransition)
    
    if let popupTransition = animator as? PopupTransition {
      XCTAssertEqual(popupTransition.state, .dismissing)
    }
  }
  
  func test_popupTransition_presentingDuration() {
    let transition = PopupTransition(state: .presenting)
    let duration = transition.transitionDuration(using: nil)
    
    XCTAssertEqual(duration, 0.3)
  }
  
  func test_popupTransition_dismissingDuration() {
    let transition = PopupTransition(state: .dismissing)
    let duration = transition.transitionDuration(using: nil)
    
    XCTAssertEqual(duration, 0.25)
  }
}