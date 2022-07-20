//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI
import Combine

@available(iOS 13.0, *)
struct PaywallTrackModifier: ViewModifier {
  @Binding var shouldTrack: Bool
  @State private var programmaticallySetShouldPresent = false
  @State private var isInternallyPresenting = false
  var event: String
  var params: [String: Any]
  var presentationStyleOverride: PaywallPresentationStyle?
  var onPresent: ((PaywallInfo) -> Void)?
  var onDismiss: PaywallDismissalCompletionBlock?
  var onSkip: PaywallSkipCompletionBlock?

  func body(content: Content) -> some View {
    content
      .onReceive(Just(shouldTrack)) { _ in
        updatePresentation(shouldTrack)
      }
  }

  private func updatePresentation(_ shouldPresent: Bool) {
    if shouldPresent {
      // Stops internallyPresent from being called twice due to state changes.
      if isInternallyPresenting {
        return
      }

      let trackableEvent = UserInitiatedEvent.Track(
        rawName: event,
        canImplicitlyTriggerPaywall: false,
        customParameters: params
      )
      let result = Paywall.track(trackableEvent)

      isInternallyPresenting = true

      Paywall.internallyPresent(
        .explicitTrigger(result.data),
        presentationStyleOverride: presentationStyleOverride ?? .none,
        onPresent: onPresent,
        onDismiss: { result in
          self.programmaticallySetShouldPresent = true
          self.shouldTrack = false
          self.isInternallyPresenting = false
          onDismiss?(result)
        },
        onSkip: { reason in
          self.programmaticallySetShouldPresent = true
          self.shouldTrack = false
          self.isInternallyPresenting = false
          onSkip?(reason)
        }
      )
    } else {
      // When states change in SwiftUI views, the shouldTrack state seems to get temporarily
      // reset to false as it rerenders the view. This incorrectly calls Paywall.dismiss().
      // Also, when views get set up for the first time, Paywall.dismiss() was being called.
      // This guards against that.
      guard isInternallyPresenting else {
        // This prevents Paywall.dismiss() being called when programmatically setting shouldTrack
        // to false.
        if programmaticallySetShouldPresent {
          programmaticallySetShouldPresent = false
          return
        }
        return
      }

      Paywall.dismiss()
    }
  }
}
