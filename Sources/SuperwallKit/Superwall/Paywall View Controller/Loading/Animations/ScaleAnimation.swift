//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/10/2022.
//

import SwiftUI

struct ScaleAnimationModifier: ViewModifier {
  let amount: CGFloat

  func body(content: Content) -> some View {
    content
      .scaleEffect(amount)
      .animation(.spring, value: amount)
  }
}

extension View {
  func scaleAnimation(for amount: CGFloat) -> some View {
    ModifiedContent(
      content: self,
      modifier: ScaleAnimationModifier(amount: amount)
    )
  }
}
