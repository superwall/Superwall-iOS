//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/03/2022.
//

import SwiftUI
import Combine

@available(iOS 13.0, *)
struct PaywallTriggerModifier: ViewModifier {
  @Binding var shouldPresent: Bool
  @State private var manuallySetShouldPresent = false
  var event: String?
  var params: [String: Any]
  var onPresent: ((PaywallInfo?) -> Void)?
  var onDismiss: ((PaywallDismissalResult) -> Void)?
  var onFail: ((NSError) -> Void)?

  func body(content: Content) -> some View {
    content
      .onReceive(Just(shouldPresent)) { _ in
        updatePresentation(shouldPresent)
      }
  }

  private func updatePresentation(_ shouldPresent: Bool) {
    if shouldPresent {
      // TODO: We are showing the default paywall here if no event name provided to trigger.
      // Double check that this is correct
      var eventInfo: PresentationInfo = .defaultPaywall

      if let name = event {
        let trackableEvent = UserInitiatedEvent.Track(
          rawName: name,
          canImplicitlyTriggerPaywall: false,
          customParameters: params
        )
        let result = Paywall.track(trackableEvent)
        eventInfo = .explicitTrigger(result.data)
      }

      Paywall.internallyPresent(
        eventInfo,
        onPresent: onPresent,
        onDismiss: { result in
          self.manuallySetShouldPresent = true
          self.shouldPresent = false
          onDismiss?(result)
        },
        onFail: { error in
          self.manuallySetShouldPresent = true
          self.shouldPresent = false
          onFail?(error)
        }
      )
    } else {
      // This prevents Paywall.dismiss() being called twice when manually setting shouldPresent.
      if manuallySetShouldPresent {
        manuallySetShouldPresent = false
        return
      }
      Paywall.dismiss()
    }
  }
}
