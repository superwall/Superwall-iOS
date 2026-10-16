//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/10/2022.
//

import SwiftUI

#if os(macOS)
struct DarkBlurView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let blurEffectView = NSVisualEffectView()
    blurEffectView.material = .hudWindow
    blurEffectView.blendingMode = .withinWindow
    blurEffectView.state = .active
    blurEffectView.appearance = NSAppearance(named: .darkAqua)
    return blurEffectView
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#else
struct DarkBlurView: UIViewRepresentable {
  func makeUIView(context: Context) -> UIVisualEffectView {
    let blurEffectView = UIVisualEffectView(
      effect: UIBlurEffect(style: .systemUltraThinMaterialDark)
    )
    return blurEffectView
  }

  func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
#endif

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
