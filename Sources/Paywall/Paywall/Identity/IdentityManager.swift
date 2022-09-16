//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation
import Combine

final class IdentityManager {
  enum IdentityError: Error {
    case configNotCalled
    case missingAppUserId
    case alreadyLoggedIn
  }

  private let storage: Storage
  private let configManager: ConfigManager

  init(
    storage: Storage,
    configManager: ConfigManager
  ) {
    self.storage = storage
    self.configManager = configManager
  }
/*
  /// Logs user in and waits for assignments to return before firing triggers.
  func logIn(
    userId: String
  ) async throws  {
    // Make sure config has been called before logging in.
    if configManager.config == nil {
      throw IdentityError.configNotCalled
    }

    // Make sure the user isn't already logged in.
    guard storage.appUserId == nil else {
      throw IdentityError.alreadyLoggedIn
    }

    // Remove excess characters and check they userId isn't empty.
    let userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    if userId.isEmpty {
      throw IdentityError.missingAppUserId
    }

    storage.appUserId = userId

    await configManager.loadAssignments()
    
    if configCalled {
      getASsignments() {

      }
    }
    let blockingAssignmentCall = PreConfigAssignmentCall(isBlocking: true)
    TriggerDelayManager.shared.cachePreConfigAssignmentCall(blockingAssignmentCall)

    // From here config -> assignments -> fire triggers ->
    // Wait for assignments to return before firing triggers.
  }

  /**
    On login -> Does some
   */


  func identify(with userId: String) {
    guard let outcome = StorageLogic.identify(
      newUserId: userId,
      oldUserId: appUserId
    ) else {
      loadAssignmentsIfNeeded()
      return
    }

    appUserId = userId

    switch outcome {
    case .reset:
      TriggerDelayManager.shared.appUserIdAfterReset = appUserId
      Paywall.reset()
    case .loadAssignments:
      if TriggerDelayManager.shared.appUserIdAfterReset == nil {
        loadAssignments()
      } else {
        loadAssignmentsAfterConfig(isBlocking: true)
        TriggerDelayManager.shared.appUserIdAfterReset = nil
      }
    }
  }
*/
  func createAccount(
    userId: String,
    completion: () -> Void
  ) {

  }

  func logOut() {

  }

  func reset() {

  }
}
