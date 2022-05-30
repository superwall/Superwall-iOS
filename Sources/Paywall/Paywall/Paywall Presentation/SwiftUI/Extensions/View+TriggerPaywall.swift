//
//  File.swift
//  
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI

@available(iOS 13.0, *)
extension View {
  /// Shows a paywall to the user when: An analytics event you provide is tied to an active trigger inside a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); the user matches a rule in the campaign; and a binding to a Boolean value that you provide is true.
  ///
  /// Triggers enable you to retroactively decide where or when to show a specific paywall in your app. Use this method when you want to remotely control paywall presentation in response to your own analytics event and utilize completion handlers associated with the paywall presentation state.
  ///
  /// Before using this method, you'll first need to create a campaign and add a trigger associated with the event name on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. Paywalls are sticky, in that when a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule.
  ///
  /// If you don't want to use any completion handlers, consider using ``Paywall/Paywall/track(_:_:)-2vkwo`` to implicitly trigger a paywall.
  ///
  /// The example below triggers a paywall when the user toggles the `showPaywall` variable by tapping on the “Collect Gems” button. The paywall will only show if the trigger for the `collectGems` event is active in the [Superwall Dashboard](https://superwall.com/dashboard) and the user doesn't have an active subscription:
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
  ///             Text("Collect Gems")
  ///           }
  ///         )
  ///         .triggerPaywall(
  ///           forEvent: "DidCollectGems",
  ///           withParams: ["gemCount": 30],
  ///           shouldPresent: $showPaywall,
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
  ///             if error.code == 4000 {
  ///               print("The user did not match any rules")
  ///             } else if error.code == 4001 {
  ///               print("The user is in a holdout group")
  ///             } else {
  ///               print("did fail", error)
  ///             }
  ///           }
  ///         )
  ///       }
  ///     }
  ///
  /// For more information, see <doc:Triggering>.
  ///
  /// **Please note**:
  /// In order to trigger a paywall, the SDK must have been configured using ``Paywall/Paywall/configure(apiKey:userId:delegate:)``.
  ///
  /// - Parameters:
  ///   - event: The name of the event you wish to trigger.
  ///   - params: Parameters you wish to pass along to the trigger.  You can refer to these parameters in the rules you define in your campaign.
  ///   - shouldPresent: A binding to a Boolean value that determines whether to present a paywall.
  ///
  ///     The system sets `shouldPresent` to false if the trigger is not active or when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing.
  ///   - onPresent: A closure that's called after the paywall is presented. Accepts a `PaywallInfo?` object containing information about the paywall. Defaults to `nil`.
  ///   - onDismiss: The closure to execute after the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing.
  ///
  ///     Accepts a `PaywallDismissalResult` object. This has a `paywallInfo` property containing information about the paywall and a `state` that tells you why the paywall was dismissed.
  ///     This closure will not be called if you programmatically set `isPresented` to `false` to dismiss the paywall.
  ///
  ///     Defaults to `nil`.
  ///   - onFail: A completion block that gets called when the paywall's presentation fails. Defaults to `nil`. Accepts an `NSError` with more details. It is recommended to check the error code to handle the onFail callback. If the error code is `4000`, it means the user didn't match any rules. If the error code is `4001` it means the user is in a holdout group. Otherwise, a `404` error code means an error occurred.
  public func triggerPaywall(
    forEvent event: String,
    withParams params: [String: Any]? = nil,
    shouldPresent: Binding<Bool>,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((PaywallDismissalResult) -> Void)? = nil,
    onFail: ((NSError) -> Void)? = nil
  ) -> some View {
    self.modifier(
      PaywallTriggerModifier(
        shouldPresent: shouldPresent,
        event: event,
        params: params ?? [:],
        onPresent: onPresent,
        onDismiss: onDismiss,
        onFail: onFail
      )
    )
  }
}
