//
//  Color.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI
import UIKit

extension Color {
  static var primaryTeal: Color {
    Color("PrimaryTeal")
  }

  static var neutral: Color {
    Color("Neutral")
  }
}

extension UIColor {
  static var neutral: UIColor {
    // swiftlint:disable:next force_unwrapping
    UIColor(named: "Neutral")!
  }
}
