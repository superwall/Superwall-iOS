//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI

@available(iOS 13.0, *)
extension View {
  public func triggerPaywall(
    event: String? = nil,
    params: [String: Any]? = nil,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((PaywallDismissalResult) -> Void)? = nil,
    onFail: ((NSError) -> Void)? = nil
  ) -> some View {
    var eventData: EventData?

    if let event = event {
      eventData = Paywall.track(event, [:], params ?? [:], handleTrigger: false)
    }

    Paywall.internallyPresent(
      fromEvent: eventData,
      onPresent: onPresent,
      onDismiss: onDismiss,
      onFail: onFail
    )

    return self
  }
}
