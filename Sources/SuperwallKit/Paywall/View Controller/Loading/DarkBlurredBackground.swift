//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/10/2022.
//

import SwiftUI

struct DarkBlurView: UIViewRepresentable {
  func makeUIView(context: Context) -> UIVisualEffectView {
    let blurEffectView = UIVisualEffectView(
      effect: UIBlurEffect(style: .systemUltraThinMaterialDark)
    )
    return blurEffectView
  }

  func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct DarkBlurredBackground: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(
        DarkBlurView()
          .clipShape(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
          )
      )
  }
}

extension View {
  func darkBlurredBackground() -> some View {
    ModifiedContent(
      content: self,
      modifier: DarkBlurredBackground()
    )
  }
}
