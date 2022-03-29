//
//  View+PresentPaywall.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI

@available(iOS 13.0, *)
extension View {
  /// Presents a paywall to the user when a binding to a Boolean value that you provide is true.
  ///
  /// Use this method to present a paywall to the user when a Boolean value you provide is `true`.
  ///
  /// The paywall assigned to the user is determined by your settings in the [Superwall Dashboard](https://superwall.com/dashboard). Once a user is assigned a paywall, they will continue to see the same paywall, even when the paywall is turned off, unless you reassign them to a new one.
  ///
  /// Paywalls are not shown to users who have an active subscription.
  ///
  /// The example below displays a paywall when the user toggles the `showPaywall` variable by tapping on the “Toggle Paywall” button:
  ///
  ///     struct ContentView: View {
  ///       @State private var showPaywall = false
  ///
  ///       var body: some View {
  ///         Button(
  ///           action: {
  ///             showPaywall.toggle()
  ///           },
  ///           label: {
  ///             Text("Toggle Paywall")
  ///           }
  ///         )
  ///         .presentPaywall(
  ///           isPresented: $showPaywall,
  ///           onPresent: { paywallInfo in
  ///             print("paywall info is", paywallInfo)
  ///           },
  ///           onDismiss: { result in
  ///             switch result.state {
  ///             case .closed:
  ///               print("User dismissed the paywall.")
  ///             case .purchased(productId: let productId):
  ///               print("Purchased a product with id \(productId), then dismissed.")
  ///             case .restored:
  ///               print("Restored purchases, then dismissed.")
  ///             }
  ///           },
  ///           onFail: { error in
  ///             print("did fail", error)
  ///           }
  ///         )
  ///       }
  ///     }
  ///
  /// For more information, see <doc:PresentingInSwiftUI>.
  ///
  /// **Please note**:
  /// In order to present a paywall, the paywall must first be created and enabled in the [Superwall Dashboard](https://superwall.com/dashboard) and the SDK configured using ``Paywall/Paywall/configure(apiKey:userId:delegate:)``.
  ///
  /// - Parameters:
  ///   - isPresented: A binding to a Boolean value that determines whether to present a paywall that's determined by the SDK.
  ///
  ///     When the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing, the system sets `isPresented` to `false`.
  ///   - onPresent: A closure that's called after the paywall is presented. Accepts a `PaywallInfo?` object containing information about the paywall. Defaults to `nil`.
  ///   - onDismiss: The closure to execute after the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing.
  ///
  ///     Accepts a `PaywallDismissalResult` object. This has a `paywallInfo` property containing information about the paywall and a `state` that tells you why the paywall was dismissed.
  ///     This closure will not be called if you programmatically set `isPresented` to `false` to dismiss the paywall.
  ///
  ///     Defaults to `nil`.
  ///   - onFail: A closure that's called when the paywall fails to present, either because an error occured or because all paywalls are off in the Superwall Dashboard.
  ///     Accepts an `NSError?` with more details. Defaults to `nil`.
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
