//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/08/2022.
//

import Combine

// TODO: hasDelay needs to be removed such that the internal paywall presentation/implicit trigger handler can use an await call to zip call below instead.
// TODO: Check identity stuff on calling reset()

class TriggerDelayManager {
  static let shared = TriggerDelayManager()
  private(set) var triggersFiredPreConfig: [PreConfigTrigger] = []
  private var cancellable: AnyCancellable?
/*
  init() {
    waitToFireDelayedTriggers()
  }

  func waitToFireDelayedTriggers() {
    cancellable = ConfigManager.shared.$config
      .zip(IdentityManager.shared.identityPublisher)
      .sink { completion in
        if completion == .finished {
          self.fireDelayedTriggers()
        }
      } receiveValue: { _ in }
  }*/

  func handleDelayedContent(
    storage: Storage = .shared,
    configManager: ConfigManager = .shared
  ) async {
    // If the user has called identify with a diff ID, we call reset.
    // Then we wait until config has returned before identifying again.
    //if let appUserIdAfterReset = appUserIdAfterReset {
      //TODO: FIGURE THIS OUT
      //    storage.identify(with: appUserIdAfterReset)
    //}
  }

  func fireDelayedTriggers(
    storage: Storage = .shared,
    paywall: Paywall = .shared
  ) {
    /*triggersFiredPreConfig.forEach { trigger in
      switch trigger.presentationInfo.triggerType {
      case .implicit:
        guard let eventData = trigger.presentationInfo.eventData else {
          return
        }
        paywall.handleImplicitTrigger(forEvent: eventData)
      case .explicit:
        Paywall.internallyPresent(
          trigger.presentationInfo,
          paywallOverrides: trigger.paywallOverrides,
          paywallState: trigger.paywallState
        )
      }
    }
    clearPreConfigTriggers()*/
  }

  func cachePreConfigTrigger(_ trigger: PreConfigTrigger) {
    triggersFiredPreConfig.append(trigger)
  }

  func clearPreConfigTriggers() {
    triggersFiredPreConfig.removeAll()
  }
}
