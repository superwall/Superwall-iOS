//
//  UIView+SpringAnimation.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if !os(macOS)
extension UIView {
  class func springAnimate(
    withDuration duration: TimeInterval = 0.618,
    delay: TimeInterval = 0,
    animations: @escaping () -> Void,
    completion: ((Bool) -> Void)? = nil
  ) {
    UIView.animate(
      withDuration: duration,
      delay: delay,
      usingSpringWithDamping: 0.8,
      initialSpringVelocity: 1.2,
      options: [.allowUserInteraction, .curveEaseInOut],
      animations: animations,
      completion: completion
    )
  }

  class func springAnimateLong(
    withDuration duration: TimeInterval = 1.0,
    delay: TimeInterval = 0,
    animations: @escaping () -> Void,
    completion: ((Bool) -> Void)? = nil
  ) {
    UIView.animate(
      withDuration: duration,
      delay: delay,
      usingSpringWithDamping: 0.8,
      initialSpringVelocity: 1.2,
      options: [.allowUserInteraction, .curveEaseInOut],
      animations: animations,
      completion: completion
    )
  }
}
#endif
