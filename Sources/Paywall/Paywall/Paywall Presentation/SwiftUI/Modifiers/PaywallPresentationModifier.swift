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
  @State private var programmaticallySetIsPresented = false
  @State private var isInternallyPresenting = false
  var presentationStyleOverride: PaywallPresentationStyle?
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
      // Stops internallyPresent from being called twice due to state changes.
      if isInternallyPresenting {
        return
      }
      isInternallyPresenting = true
      Paywall.internallyPresent(
        .defaultPaywall,
        presentationStyleOverride: presentationStyleOverride ?? .none,
        onPresent: onPresent,
        onDismiss: { result in
          self.programmaticallySetIsPresented = true
          self.isPresented = false
          self.isInternallyPresenting = false
          onDismiss?(result)
        },
        onFail: { error in
          self.programmaticallySetIsPresented = true
          self.isPresented = false
          self.isInternallyPresenting = false
          onFail?(error)
        }
      )
    } else {
      // When states change in SwiftUI views, the isPresented state seems to get temporarily
      // reset to false as it rerenders the view. This incorrectly calls Paywall.dismiss().
      // Also, when views get set up for the first time, Paywall.dismiss() was being called.
      // This guards against that.
      guard isInternallyPresenting else {
        // This prevents Paywall.dismiss() being called when programmatically setting isPresented
        // to false.
        if programmaticallySetIsPresented {
          programmaticallySetIsPresented = false
          return
        }
        return
      }
      Paywall.dismiss()
    }
  }
}
