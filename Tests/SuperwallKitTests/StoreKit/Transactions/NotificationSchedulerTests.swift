//
//  File.swift
//
//
//  Created by Yusuf Tör on 15/09/2023.
//
// swiftlint:disable all

import Testing
@testable import SuperwallKit
import StoreKit

@Suite(.serialized)
struct NotificationSchedulerTests {
  class MockNotificationCenter: NotificationAuthorizable {
    let settings: NotificationSettings
    var pendingRequests: [UNNotificationRequest] = []

    init(settings: NotificationSettings) {
      self.settings = settings
    }

    var requests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
      return true
    }

    func notificationSettings() async -> NotificationSettings {
      return settings
    }

    func add(_ request: UNNotificationRequest) async throws {
      requests.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
      return pendingRequests
    }
  }

  class Factory: DeviceHelperFactory {
    let isSandbox: Bool

    init(isSandbox: Bool = false) {
      self.isSandbox = isSandbox
    }

    func makeIsSandbox() -> Bool {
      return isSandbox
    }
    func makeDeviceInfo() -> DeviceInfo {
      return .init(appInstalledAtString: "", locale: "")
    }
    func makeSessionDeviceAttributes() async -> [String : Any] {
      return [:]
    }
  }

  class AuthorizedNotificationSettings: NotificationSettings {
    var authorizationStatus: UNAuthorizationStatus {
      return .authorized
    }
  }

  @Test("Schedules notification with correct content when not in sandbox")
  func scheduleNotifications_noSandbox() async {
    let factory = Factory(isSandbox: false)
    let notification: LocalNotification = .stub()
    let notifications: [LocalNotification] = [notification]
    let notificationCenter = MockNotificationCenter(settings: AuthorizedNotificationSettings())
    let paywallId = "test_paywall_123"

    await NotificationScheduler.shared.scheduleNotifications(
      notifications,
      fromPaywallId: paywallId,
      factory: factory,
      notificationCenter: notificationCenter
    )

    #expect(notificationCenter.requests.count == 1)

    let request = notificationCenter.requests.first!
    #expect(request.content.title == notification.title)
    #expect(request.content.body == notification.body)
    #expect(request.content.subtitle == notification.subtitle)
    #expect((request.trigger as! UNTimeIntervalNotificationTrigger).timeInterval == notification.delay / 1000)
  }

  @Test("Schedules notification with reduced delay when in sandbox")
  func scheduleNotifications_sandbox() async {
    let factory = Factory(isSandbox: true)
    let notification: LocalNotification = .stub()
    let notifications: [LocalNotification] = [notification]
    let notificationCenter = MockNotificationCenter(settings: AuthorizedNotificationSettings())
    let paywallId = "test_paywall_123"

    await NotificationScheduler.shared.scheduleNotifications(
      notifications,
      fromPaywallId: paywallId,
      factory: factory,
      notificationCenter: notificationCenter
    )

    #expect(notificationCenter.requests.count == 1)

    let request = notificationCenter.requests.first!
    #expect(request.content.title == notification.title)
    #expect(request.content.body == notification.body)
    #expect(request.content.subtitle == notification.subtitle)
    #expect((request.trigger as! UNTimeIntervalNotificationTrigger).timeInterval == notification.delay / 1000 / 24 / 60)
  }

  @Test("Uses deterministic identifier based on paywall ID and notification type")
  func scheduleNotifications_deterministicIdentifier() async {
    let factory = Factory()
    let notification: LocalNotification = .stub()
    let notifications: [LocalNotification] = [notification]
    let notificationCenter = MockNotificationCenter(settings: AuthorizedNotificationSettings())
    let paywallId = "my_paywall"

    await NotificationScheduler.shared.scheduleNotifications(
      notifications,
      fromPaywallId: paywallId,
      factory: factory,
      notificationCenter: notificationCenter
    )

    #expect(notificationCenter.requests.count == 1)

    let expectedIdentifier = "\(NotificationScheduler.superwallIdentifier)-\(paywallId)-TRIAL_STARTED"
    #expect(notificationCenter.requests.first!.identifier == expectedIdentifier)
  }

  @Test("Does not schedule notification if already pending with same identifier")
  func scheduleNotifications_skipIfAlreadyPending() async {
    let factory = Factory()
    let notification: LocalNotification = .stub()
    let notifications: [LocalNotification] = [notification]
    let notificationCenter = MockNotificationCenter(settings: AuthorizedNotificationSettings())
    let paywallId = "my_paywall"

    // Pre-populate pending requests with the same identifier
    let existingIdentifier = "\(NotificationScheduler.superwallIdentifier)-\(paywallId)-TRIAL_STARTED"
    let existingRequest = UNNotificationRequest(
      identifier: existingIdentifier,
      content: UNNotificationContent(),
      trigger: nil
    )
    notificationCenter.pendingRequests = [existingRequest]

    await NotificationScheduler.shared.scheduleNotifications(
      notifications,
      fromPaywallId: paywallId,
      factory: factory,
      notificationCenter: notificationCenter
    )

    // Should not have added any new requests
    #expect(notificationCenter.requests.isEmpty)
  }

  @Test("Schedules notification if pending notification has different identifier")
  func scheduleNotifications_schedulesIfDifferentIdentifier() async {
    let factory = Factory()
    let notification: LocalNotification = .stub()
    let notifications: [LocalNotification] = [notification]
    let notificationCenter = MockNotificationCenter(settings: AuthorizedNotificationSettings())
    let paywallId = "my_paywall"

    // Pre-populate pending requests with a different identifier
    let existingRequest = UNNotificationRequest(
      identifier: "\(NotificationScheduler.superwallIdentifier)-different_paywall-TRIAL_STARTED",
      content: UNNotificationContent(),
      trigger: nil
    )
    notificationCenter.pendingRequests = [existingRequest]

    await NotificationScheduler.shared.scheduleNotifications(
      notifications,
      fromPaywallId: paywallId,
      factory: factory,
      notificationCenter: notificationCenter
    )

    // Should have added the new request
    #expect(notificationCenter.requests.count == 1)
  }
}
