//
//  File.swift
//  
//
//  Created by Yusuf Tör on 01/02/2023.
//

import SwiftUI

struct PaddingListenerViewModifier: ViewModifier {
  let movedUp: Published<Bool>.Publisher
  let model: LoadingModel
  let maxPadding: CGFloat

  func body(content: Content) -> some View {
    content
      .onAppear()
      .onReceive(movedUp) { movedUp in
        if movedUp {
          model.padding = maxPadding
        } else {
          model.padding = 0
        }
      }
  }
}

extension View {
  func listen(
    to movedUp: Published<Bool>.Publisher,
    fromModel model: LoadingModel,
    maxPadding: CGFloat
  ) -> some View {
    ModifiedContent(
      content: self,
      modifier: PaddingListenerViewModifier(
        movedUp: movedUp,
        model: model,
        maxPadding: maxPadding
      )
    )
  }
}
