//
//  PaywallPresentationModifier.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI
import Combine

@available(iOS 13.0, *)
struct PaywallPresentationModifier: ViewModifier {
  @Binding var isPresented: Bool
  @State private var manuallySetIsPresented = false
  var onPresent: ((PaywallInfo?) -> Void)?
  var onDismiss: ((PaywallDismissalResult) -> Void)?
  var onFail: ((NSError) -> Void)?

  func body(content: Content) -> some View {
    content
      .onReceive(Just(isPresented)) { _ in
        updatePresentation(isPresented)
      }
  }

  private func updatePresentation(_ isPresented: Bool) {
    if isPresented {
      Paywall.internallyPresent(
        onPresent: onPresent,
        onDismiss: { result in
          self.manuallySetIsPresented = true
          self.isPresented = false
          onDismiss?(result)
        },
        onFail: { error in
          self.manuallySetIsPresented = true
          self.isPresented = false
          onFail?(error)
        }
      )
    } else {
      // This prevents Paywall.dismiss() being called twice when manually setting isPresented.
      if manuallySetIsPresented {
        manuallySetIsPresented = false
        return
      }
      Paywall.dismiss()
    }
  }
}
