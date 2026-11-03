//
//  SWPaywallFactory.swift
//  Superwall
//
//  Created by Yusuf Tör on 03/03/2022.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
enum ButtonFactory {
  /// A borderless button showing a template image from the SDK's asset
  /// catalog, tinted with `contentTintColor`.
  static func make(
    imageNamed name: String,
    target: AnyObject,
    action: Selector
  ) -> NSButton {
    guard let image = Bundle.module.image(forResource: name) else {
      return NSButton()
    }
    image.isTemplate = true
    let button = NSButton(
      image: image,
      target: target,
      action: action
    )
    button.isBordered = false
    button.imageScaling = .scaleProportionallyUpOrDown
    button.translatesAutoresizingMaskIntoConstraints = false
    button.isHidden = true
    return button
  }
}
#else
enum ButtonFactory {
  static func make(
    imageNamed name: String,
    target: Any,
    action: Selector
  ) -> UIButton {
    let button = UIButton()
    guard let image = UIImage(
      named: name,
      in: Bundle.module,
      compatibleWith: nil
    ) else {
      return UIButton()
    }
    button.setImage(image, for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(
      target,
      action: action,
      for: .primaryActionTriggered
    )
    button.isHidden = true
    return button
  }
}
#endif
