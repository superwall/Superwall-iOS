//
//  ShimmerModifier.swift
//
//
//  Created by Yusuf Tör on 23/09/2026.
//

import SwiftUI

/// Sweeps a highlight across a placeholder so it reads as loading rather than as a grey bar.
///
/// The highlight is masked to the placeholder's own shape, and it stays put under Reduce Motion.
@available(iOS 15.0, *)
struct ShimmerModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @State private var phase: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .overlay(
        GeometryReader { geometry in
          let width = geometry.size.width
          LinearGradient(
            colors: [.clear, highlight, .clear],
            startPoint: .leading,
            endPoint: .trailing
          )
          .frame(width: width * 0.6)
          // Travels from fully off the leading edge to fully off the trailing edge.
          .offset(x: -width * 0.6 + phase * width * 1.6)
        }
        .mask(content)
        .opacity(reduceMotion ? 0 : 1)
      )
      .onAppear {
        if reduceMotion {
          return
        }
        withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
          phase = 1
        }
      }
  }

  private var highlight: Color {
    colorScheme == .dark ? .white.opacity(0.18) : .white.opacity(0.7)
  }
}

@available(iOS 15.0, *)
extension View {
  func shimmering() -> some View {
    modifier(ShimmerModifier())
  }
}
