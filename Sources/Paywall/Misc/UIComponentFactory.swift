//
//  SWPaywallFactory.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import UIKit

enum UIComponentFactory {
  static func makeButton(
    imageNamed name: String,
    target: Any,
    action: Selector
  ) -> UIButton {
    let button = UIButton()
    guard let exitImage = UIImage(
      named: name,
      in: Bundle.module,
      compatibleWith: nil
    ) else {
      return UIButton()
    }
    button.setImage(exitImage, for: .normal)
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
