//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/01/2023.
//

import Foundation
@testable import SuperwallKit

struct StoreKitCoordinatorFactoryMock: StoreKitCoordinatorFactory {
  let coordinator: StoreKitCoordinator

  func makeStoreKitCoordinator() -> StoreKitCoordinator {
    return coordinator
  }
}
