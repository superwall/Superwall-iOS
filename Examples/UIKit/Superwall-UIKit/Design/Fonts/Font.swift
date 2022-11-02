//
//  Font.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit

extension UIFont {
  static func rubik(_ size: Styles.FontSize) -> UIFont {
    // swiftlint:disable:next force_unwrapping
    return UIFont(name: "Rubik-Regular", size: size.rawValue)!
  }

  static func rubikBold(_ size: Styles.FontSize) -> UIFont {
    // swiftlint:disable:next force_unwrapping
    return UIFont(name: "Rubik-Bold", size: size.rawValue)!
  }
}
