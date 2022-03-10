//
//  View+PresentPaywall.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI

@available(iOS 13.0, *)
extension View {
  public func presentPaywall(
    isPresented: Binding<Bool>,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((PaywallDismissalResult) -> Void)? = nil,
    onFail: ((NSError) -> Void)? = nil
  ) -> some View {
    self.modifier(
      PaywallPresentationModifier(
        isPresented: isPresented,
        onPresent: onPresent,
        onDismiss: onDismiss,
        onFail: onFail
      )
    )
  }
}
