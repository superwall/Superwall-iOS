//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/01/2023.
//

import Foundation
@testable import SuperwallKit

final class StoreKitCoordinatorFactoryMock: StoreKitCoordinatorFactory {
  let coordinator: StoreKitCoordinator

  init(coordinator: StoreKitCoordinator) {
    self.coordinator = coordinator
  }

  func makeStoreKitCoordinator() -> StoreKitCoordinator {
    return coordinator
  }
}
