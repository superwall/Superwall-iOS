//
//  Superwall+PushNotifications.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 27/10/2026.
//

import Foundation
import UserNotifications

// MARK: - Push Notifications
extension Superwall {
  /// Registers the device's APNs token with Superwall, so Superwall can send
  /// it push notifications.
  ///
  /// Call this from your app delegate whenever the system hands you a token.
  /// It's safe to call on every launch: an unchanged token isn't sent again.
  ///
  /// ```swift
  /// func application(
  ///   _ application: UIApplication,
  ///   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  /// ) {
  ///   Superwall.shared.setPushToken(deviceToken)
  /// }
  /// ```
  ///
  /// The token is only sent to Superwall, and never appears in
  /// ``SuperwallDelegate/handleSuperwallEvent(withInfo:)-50exd``, user
  /// attributes or audience filters. Along with it, Superwall receives the
  /// notification permission the user has granted, which is checked again
  /// each time the app becomes active.
  ///
  /// The SDK doesn't swizzle your app delegate and doesn't request
  /// notification permission or register for remote notifications itself.
  ///
  /// - Parameter deviceToken: The token from
  ///   `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
  @objc(setPushToken:)
  public func setPushToken(_ deviceToken: Data) {
    dependencyContainer.notificationTokenManager.setPushToken(deviceToken)
  }

  /// Stops Superwall sending push notifications to this device.
  ///
  /// The choice is remembered across launches, `reset()` and `identify(userId:)`
  /// until you call ``optInToNotifications()``. It doesn't change the
  /// system's notification permission.
  @objc
  public func optOutOfNotifications() {
    dependencyContainer.notificationTokenManager.setEnabled(false)
  }

  /// Lets Superwall send push notifications to this device again after
  /// ``optOutOfNotifications()``.
  ///
  /// Devices are opted in by default, so you only need this to undo an
  /// opt-out.
  @objc
  public func optInToNotifications() {
    dependencyContainer.notificationTokenManager.setEnabled(true)
  }

  /// Tells Superwall the user opened a notification, so it can measure the
  /// notifications it sends.
  ///
  /// Call this from your `UNUserNotificationCenterDelegate`. Notifications that
  /// Superwall didn't send are ignored, so you can pass every response in:
  ///
  /// ```swift
  /// func userNotificationCenter(
  ///   _ center: UNUserNotificationCenter,
  ///   didReceive response: UNNotificationResponse
  /// ) async {
  ///   Superwall.shared.handleNotificationResponse(response)
  /// }
  /// ```
  ///
  /// Dismissals (`UNNotificationDismissActionIdentifier`) aren't counted as
  /// opens.
  ///
  /// - Parameter response: The user's response to the notification.
  @objc(handleNotificationResponse:)
  public func handleNotificationResponse(_ response: UNNotificationResponse) {
    guard response.actionIdentifier != UNNotificationDismissActionIdentifier else {
      return
    }
    dependencyContainer.notificationTokenManager.trackOpen(
      userInfo: response.notification.request.content.userInfo
    )
  }
}
