//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/10/2022.
//

#if canImport(WebKit)
import SwiftUI

struct BottomPaddingAnimationModifier: ViewModifier {
  let amount: CGFloat

  func body(content: Content) -> some View {
    content
      .padding(.bottom, amount)
      .animation(.spring, value: amount)
  }
}

extension View {
  func bottomPaddingAnimation(for amount: CGFloat) -> some View {
    ModifiedContent(
      content: self,
      modifier: BottomPaddingAnimationModifier(amount: amount)
    )
  }
}
#endif
