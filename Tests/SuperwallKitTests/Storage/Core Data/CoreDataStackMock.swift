//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//
// swiftlint:disable all

import CoreData
@testable import SuperwallKit

@available(iOS 14.0, *)
final class CoreDataStackMock: CoreDataStack {
  init(useInMemoryStore: Bool = true) {
    // Create persistent container
    let persistentContainer = NSPersistentContainer(
      name: CoreDataStack.modelName,
      managedObjectModel: CoreDataStack.managedObject
    )

    // Configure for in-memory store if requested (default for tests)
    if useInMemoryStore {
      let description = NSPersistentStoreDescription()
      description.type = NSInMemoryStoreType
      persistentContainer.persistentStoreDescriptions = [description]
    }

    // Load the store
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

    // Initialize parent with dummy - we'll set our own
    super.init()

    guard containerError == nil else {
      return
    }

    self.persistentContainer = persistentContainer

    // Setup contexts
    let backgroundContext = persistentContainer.newBackgroundContext()
    backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    self.backgroundContext = backgroundContext

    let mainContext = persistentContainer.viewContext
    mainContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    self.mainContext = mainContext
  }

  func deleteAllEntities(named entityName: String, completion: () -> Void) {
    guard let backgroundContext = backgroundContext else {
      completion()
      return
    }

    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

    backgroundContext.performAndWait {
      do {
        try backgroundContext.executeAndMergeChanges(using: deleteRequest)
        completion()
        print("Deleted entities")
      } catch let error as NSError {
        print("Error deleting!", error)
        completion()
      }
    }
  }

  func batchInsertPlacementData(
    eventName: String,
    count: Int,
    completion: @escaping () -> Void
  ) {
    guard let backgroundContext = backgroundContext else {
      completion()
      return
    }
    
    backgroundContext.perform {
      for _ in 0..<count {
        let stub = PlacementData.stub()
          .setting(\.name, to: eventName)
        let data = try? JSONEncoder().encode(stub.parameters)
        _ = ManagedEventData(
          context: backgroundContext,
          id: stub.id,
          createdAt: stub.createdAt,
          name: stub.name,
          parameters: data ?? Data()
        )
      }
      
      do {
        if backgroundContext.hasChanges {
          try backgroundContext.save()
        }
        DispatchQueue.main.async {
          completion()
        }
      } catch {
        print("ERROR saving placement data!", error)
        DispatchQueue.main.async {
          completion()
        }
      }
    }
  }

  func batchInsertTriggerOccurrences(
    key: String,
    count: Int,
    completion: @escaping () -> Void
  ) {
    guard let backgroundContext = backgroundContext else {
      completion()
      return
    }
    
    backgroundContext.perform {
      for _ in 0..<count {
        _ = ManagedTriggerRuleOccurrence(
          context: backgroundContext,
          createdAt: Date(),
          occurrenceKey: key
        )
      }
      
      do {
        if backgroundContext.hasChanges {
          try backgroundContext.save()
        }
        DispatchQueue.main.async {
          completion()
        }
      } catch {
        print("ERROR saving trigger occurrences!", error)
        DispatchQueue.main.async {
          completion()
        }
      }
    }
  }
}
