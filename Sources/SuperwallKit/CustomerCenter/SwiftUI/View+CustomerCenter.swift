//
//  View+CustomerCenter.swift
//
//
//  Created by Claude on 20/08/2026.
//

import SwiftUI

@available(iOS 15.0, *)
private struct CustomerCenterCallbacksKey: EnvironmentKey {
  static let defaultValue = CustomerCenterCallbacksBox()
}

/// Reference box so modifiers can accumulate callbacks down the view tree.
@available(iOS 15.0, *)
final class CustomerCenterCallbacksBox {
  var callbacks = CustomerCenterCallbacks()
}

@available(iOS 15.0, *)
extension EnvironmentValues {
  var customerCenterCallbacks: CustomerCenterCallbacksBox {
    get { self[CustomerCenterCallbacksKey.self] }
    set { self[CustomerCenterCallbacksKey.self] = newValue }
  }
}

@available(iOS 15.0, *)
public extension View {
  /// Presents the Customer Center as a sheet.
  /// - Parameters:
  ///   - isPresented: Controls presentation, same as the standard `sheet` modifier.
  ///   - configuration: Overrides ``SuperwallOptions/customerCenter``. `nil` uses the options value.
  ///   - onDismiss: Called after the sheet is dismissed.
  func presentCustomerCenter(
    isPresented: Binding<Bool>,
    configuration: CustomerCenterConfiguration? = nil,
    onDismiss: (() -> Void)? = nil
  ) -> some View {
    sheet(isPresented: isPresented, onDismiss: onDismiss) {
      CustomerCenterView(configuration: configuration)
    }
  }

  /// Gate restores (e.g. require authentication). Call `resume(true)` to continue, `resume(false)` to cancel.
  func onCustomerCenterShouldRestore(
    _ handler: @escaping (_ resume: @escaping (Bool) -> Void) -> Void
  ) -> some View {
    modifier(CustomerCenterCallbackModifier { $0.shouldRestore = handler })
  }

  /// Called when the user selects an action in the Customer Center, with the purchase it applies to, if any.
  func onCustomerCenterAction(
    _ handler: @escaping (CustomerCenterAction, SubscriptionTransaction?) -> Void
  ) -> some View {
    modifier(CustomerCenterCallbackModifier { $0.didSelectAction = handler })
  }

  /// Called when the user answers a feedback survey, before the associated action is performed.
  func onCustomerCenterSurveyResponse(
    _ handler: @escaping (_ surveyId: String, _ optionId: String, _ action: CustomerCenterAction) -> Void
  ) -> some View {
    modifier(CustomerCenterCallbackModifier { $0.didCompleteSurvey = handler })
  }

  /// Called when a refund request finishes, with its outcome.
  func onCustomerCenterRefundRequest(
    _ handler: @escaping (_ productId: String, _ status: CustomerCenterRefundStatus) -> Void
  ) -> some View {
    modifier(CustomerCenterCallbackModifier { $0.didCompleteRefund = handler })
  }

  /// Called when the Customer Center is dismissed.
  func onCustomerCenterDismiss(_ handler: @escaping () -> Void) -> some View {
    modifier(CustomerCenterCallbackModifier { $0.didDismiss = handler })
  }
}

@available(iOS 15.0, *)
private struct CustomerCenterCallbackModifier: ViewModifier {
  let update: (inout CustomerCenterCallbacks) -> Void
  @Environment(\.customerCenterCallbacks) private var box

  func body(content: Content) -> some View {
    let newBox = CustomerCenterCallbacksBox()
    newBox.callbacks = box.callbacks
    update(&newBox.callbacks)
    return content.environment(\.customerCenterCallbacks, newBox)
  }
}
