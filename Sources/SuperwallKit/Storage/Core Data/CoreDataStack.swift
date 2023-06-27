//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation
import CoreData

class CoreDataStack {
  static let modelName = "SuperwallKit_Model"

  static let managedObject: NSManagedObjectModel = {
    guard let modelUrl = Bundle.module.url(
      forResource: modelName,
      withExtension: "momd"
    ) else {
      Logger.debug(
        logLevel: .error,
        scope: .coreData,
        message: "Error finding Core Data model."
      )
      return .init()
    }
    guard let model = NSManagedObjectModel(contentsOf: modelUrl) else {
      Logger.debug(
        logLevel: .error,
        scope: .coreData,
        message: "Error loading Core Data model."
      )
      return .init()
    }
    return model
  }()

  var persistentContainer: NSPersistentContainer?
  var backgroundContext: NSManagedObjectContext?
  var mainContext: NSManagedObjectContext?

  init() {
    // First load persistent container
    let persistentContainer = NSPersistentContainer(
      name: Self.modelName,
      managedObjectModel: Self.managedObject
    )

    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()
    var containerError: Error?
    persistentContainer.loadPersistentStores { _, error in
      containerError = error
      if let error = error as NSError? {
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Error loading Core Data persistent stores.",
          info: error.userInfo,
          error: error
        )
      }
      dispatchGroup.leave()
    }
    dispatchGroup.wait()
    guard containerError == nil else {
      return
    }

    self.persistentContainer = persistentContainer

    // Then load background and main context
    let backgroundContext = persistentContainer.newBackgroundContext()
    backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    self.backgroundContext = backgroundContext

    let mainContext = persistentContainer.viewContext
    mainContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    self.mainContext = mainContext
  }

  func saveContext(
    _ context: NSManagedObjectContext,
    completion: (() -> Void)? = nil
  ) {
    if persistentContainer == nil {
      completion?()
      return
    }
    context.perform {
      do {
        try context.save()
        completion?()
      } catch let error as NSError {
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Error saving to Core Data.",
          info: error.userInfo,
          error: error
        )
      }
    }
  }

  func count<T: NSFetchRequestResult>(
    for fetchRequest: NSFetchRequest<T>,
    completion: @escaping ((Int) -> Void)
  ) {
    guard
      let backgroundContext = backgroundContext,
      persistentContainer != nil
    else {
      return completion(0)
    }
    backgroundContext.perform {
      do {
        let count = try backgroundContext.count(for: fetchRequest)
        completion(count)
      } catch let error as NSError {
        Logger.debug(
          logLevel: .error,
          scope: .coreData,
          message: "Error counting from Core Data.",
          info: error.userInfo,
          error: error
        )
        completion(0)
      }
    }
  }
}
