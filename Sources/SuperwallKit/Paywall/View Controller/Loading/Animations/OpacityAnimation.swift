//
//  OpacityAnimation.swift
//  
//
//  Created by Jake Mor on 2/7/23.
//


import SwiftUI

struct OpacityAnimationModifier: ViewModifier {
  let amount: CGFloat

  func body(content: Content) -> some View {
    content
      .opacity(amount)
      .animation(.easeInOut, value: amount)
  }
}

extension View {
  func opacityAnimation(for amount: CGFloat) -> some View {
    ModifiedContent(
      content: self,
      modifier: OpacityAnimationModifier(amount: amount)
    )
  }
}

