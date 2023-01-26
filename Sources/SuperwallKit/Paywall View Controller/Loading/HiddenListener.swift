//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/10/2022.
//

import SwiftUI

struct HiddenListenerViewModifier: ViewModifier {
  let isHidden: Published<Bool>.Publisher
  let model: LoadingModel
  let maxPadding: CGFloat

  func body(content: Content) -> some View {
    content
      .onAppear()
      .onReceive(isHidden) { isHidden in
        isHidden ? hide() : show()
      }
  }

  private func show() {
    model.isAnimating = true
    model.scaleAmount = 1
    model.rotationAmount = 0
    model.padding = maxPadding
  }

  private func hide() {
    model.scaleAmount = 0.05
    model.rotationAmount = .pi
    model.isAnimating = false
    model.padding = 0
  }
}

extension View {
  func listen(
    to isHidden: Published<Bool>.Publisher,
    fromModel model: LoadingModel,
    maxPadding: CGFloat
  ) -> some View {
    ModifiedContent(
      content: self,
      modifier: HiddenListenerViewModifier(
        isHidden: isHidden,
        model: model,
        maxPadding: maxPadding
      )
    )
  }
}
