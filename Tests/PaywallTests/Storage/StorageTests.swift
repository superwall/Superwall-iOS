//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/04/2022.
//
// swiftlint:disable all
/*
import XCTest
@testable import Paywall

class StorageTests: XCTestCase {
  let queue = DispatchQueue.main
  var storage: Storage!

  override func setUp() {
    let cache = Cache(ioQueue: queue)
    storage = Storage(cache: cache)
    storage.clear()
    sleep(1)
  }

  // MARK: - recordAppInstall
  func testRecordAppInstall_freshInstall() {
      // Given
      let eventName = Paywall.EventName.appInstall.rawValue
      var tracked = false

      let trackEvent: (Trackable) -> TrackingResult = { event in

        XCTAssertEqual(event.rawName, eventName)

        tracked = true
        return .stub()
      }

      // When
        self.storage.recordAppInstall(
          trackEvent: trackEvent
        )


      // Then
        XCTAssertTrue(tracked)
  }

  func testRecordAppInstall_alreadyInstalled() {
    // Given
    let eventName = Paywall.EventName.appInstall.rawValue
    var tracked1 = false

    let trackEvent: (Trackable) -> TrackingResult = { event in
        XCTAssertEqual(event.rawName, eventName)
      tracked1 = true
      return .stub()
    }

    // Track once
    self.storage.recordAppInstall(
      trackEvent: trackEvent
    )

    sleep(1)

    XCTAssertTrue(tracked1)


    var tracked2 = false
    let trackEvent2: (Trackable) -> TrackingResult = { event in
      tracked2 = true
      return .stub()
    }

    // When: track again
    self.storage.recordAppInstall(
      trackEvent: trackEvent2
    )

    sleep(1)

    print("erm??", tracked2)
    XCTAssertFalse(tracked2)
  }
}
*/
