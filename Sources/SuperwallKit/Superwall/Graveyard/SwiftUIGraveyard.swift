//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/10/2022.
//

import SwiftUI

extension View {
  @available(*, unavailable, message: "Please use the UIKit function Superwall.track(...) instead.")
  public func triggerPaywall(
    forEvent event: String,
    withParams params: [String: Any]? = nil,
    shouldPresent: Binding<Bool>,
    products: PaywallProducts? = nil,
    presentationStyleOverride: PaywallPresentationStyle? = nil,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((PaywallDismissedResult) -> Void)? = nil,
    onFail: ((NSError) -> Void)? = nil
  ) -> some View {
    return EmptyView()
  }
}
