//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/10/2022.
//

import SwiftUI

struct RotationAnimationModifier: ViewModifier {
  let amount: CGFloat

  func body(content: Content) -> some View {
    content
      .rotationEffect(.radians(amount))
      .animation(.spring, value: amount)
  }
}

extension View {
  func rotationAnimation(for amount: CGFloat) -> some View {
    ModifiedContent(
      content: self,
      modifier: RotationAnimationModifier(amount: amount)
    )
  }
}
