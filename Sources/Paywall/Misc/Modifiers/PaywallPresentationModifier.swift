//
//  PaywallPresentationModifier.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI

@available(iOS 13.0, *)
struct PaywallPresentationModifier: ViewModifier {
  @Binding var isPresented: Bool
  @State private var userDidDismiss = false
  var onPresent: ((PaywallInfo?) -> Void)?
  var onDismiss: ((PaywallDismissalResult) -> Void)?
  var onFail: ((NSError) -> Void)?

  func body(content: Content) -> some View {
    content
      .valueChanged(
        value: isPresented,
        onChange: updatePresentation
      )
  }

  private func updatePresentation(_ isPresented: Bool) {
    if isPresented {
      Paywall.internallyPresent(
        onPresent: onPresent,
        onDismiss: { result in
          self.userDidDismiss = true
          self.isPresented = false
          onDismiss?(result)
        },
        onFail: onFail
      )
    } else {
      // This prevents Paywall.dismiss() being called twice when onDismiss gets a callback.
      if userDidDismiss {
        userDidDismiss = false
        return
      }
      Paywall.dismiss()
    }
  }
}
