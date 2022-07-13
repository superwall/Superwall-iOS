//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation
import CoreData

class CoreDataStack {
  static let modelName = "Model"

  static let managedObject: NSManagedObjectModel = {
    guard let modelUrl = Bundle.module.url(
      forResource: "Model",
      withExtension: "momd"
    ) else {
      return .init()
    }
    return NSManagedObjectModel(contentsOf: modelUrl) ?? .init()
  }()

  lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(
      name: Self.modelName,
      managedObjectModel: Self.managedObject
    )

    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        Logger.debug(
          logLevel: .debug,
          scope: .paywallCore,
          message: "Error loading Core Data persistent stores.",
          info: error.userInfo,
          error: error
        )
      }
      dispatchGroup.leave()
    }
    dispatchGroup.wait()
    return container
  }()

  lazy var backgroundContext: NSManagedObjectContext = {
    let context = persistentContainer.newBackgroundContext()
    context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    return context
  }()

  lazy var mainContext: NSManagedObjectContext = {
    let mainContext = persistentContainer.viewContext
    mainContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    return mainContext
  }()

  func saveContext(
    _ context: NSManagedObjectContext,
    completion: (() -> Void)? = nil
  ) {
    context.perform {
      do {
        try context.save()
        completion?()
      } catch let error as NSError {
        Logger.debug(
          logLevel: .debug,
          scope: .paywallCore,
          message: "Error saving to Core Data.",
          info: error.userInfo,
          error: error
        )
      }
    }
  }


  func count<T: NSFetchRequestResult>(for fetchRequest: NSFetchRequest<T>) -> Int {
    do {
      let count = try mainContext.count(for: fetchRequest)
      return count
    } catch let error as NSError {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallCore,
        message: "Error counting from Core Data.",
        info: error.userInfo,
        error: error
      )
      return 0
    }
  }
}
