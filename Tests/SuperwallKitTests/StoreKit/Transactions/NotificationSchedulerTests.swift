//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/09/2023.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit
import StoreKit

class NotificationSchedulerTests: XCTestCase {
  class NotificationCenter: NotificationAuthorizable {
    let settings: NotificationSettings

    init(settings: NotificationSettings) {
      self.settings = settings
    }

    var requests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {
      completionHandler(true, nil)
    }

    func getSettings(completionHandler: @escaping (NotificationSettings) -> Void) {
      completionHandler(settings)
    }

    func add(_ request: UNNotificationRequest) async throws {
      requests.append(request)
    }
  }

  func test_scheduleNotifications_noSandbox() async {
    class Factory: DeviceHelperFactory {
      func makeIsSandbox() -> Bool {
        return false
      }
      func makeDeviceInfo() -> DeviceInfo {
        return .init(appInstalledAtString: "", locale: "")
      }
    }

    class AuthorizedNotificationSettings: NotificationSettings {
      var authorizationStatus: UNAuthorizationStatus {
        return .authorized
      }
    }

    let factory = Factory()
    let notification: LocalNotification = .stub()
    let notifications: [LocalNotification] = [notification]
    let notificationCenter = NotificationCenter(settings: AuthorizedNotificationSettings())

    await NotificationScheduler.scheduleNotifications(
      notifications,
      factory: factory,
      notificationCenter: notificationCenter
    )


    XCTAssertEqual(notificationCenter.requests.count, 1)

    XCTAssertEqual(notificationCenter.requests.first!.content.title, notification.title)
    XCTAssertEqual(notificationCenter.requests.first!.content.body, notification.body)
    XCTAssertEqual(notificationCenter.requests.first!.content.subtitle, notification.subtitle)
    XCTAssertEqual((notificationCenter.requests.first!.trigger as! UNTimeIntervalNotificationTrigger).timeInterval, notification.delay / 1000)
  }

  func test_scheduleNotifications_sandbox() async {
    class Factory: DeviceHelperFactory {
      func makeIsSandbox() -> Bool {
        return true
      }
      func makeDeviceInfo() -> DeviceInfo {
        return .init(appInstalledAtString: "", locale: "")
      }
    }

    class AuthorizedNotificationSettings: NotificationSettings {
      var authorizationStatus: UNAuthorizationStatus {
        return .authorized
      }
    }

    let factory = Factory()
    let notification: LocalNotification = .stub()
    let notifications: [LocalNotification] = [notification]
    let notificationCenter = NotificationCenter(settings: AuthorizedNotificationSettings())

    await NotificationScheduler.scheduleNotifications(
      notifications,
      factory: factory,
      notificationCenter: notificationCenter
    )


    XCTAssertEqual(notificationCenter.requests.count, 1)

    XCTAssertEqual(notificationCenter.requests.first!.content.title, notification.title)
    XCTAssertEqual(notificationCenter.requests.first!.content.body, notification.body)
    XCTAssertEqual(notificationCenter.requests.first!.content.subtitle, notification.subtitle)
    XCTAssertEqual((notificationCenter.requests.first!.trigger as! UNTimeIntervalNotificationTrigger).timeInterval, notification.delay / 1000 / 24 / 60)
  }
}
