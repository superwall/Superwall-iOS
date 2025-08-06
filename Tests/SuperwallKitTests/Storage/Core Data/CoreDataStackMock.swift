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
  func deleteAllEntities(named entityName: String, completion: () -> Void) {
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

    do {
      try mainContext!.executeAndMergeChanges(using: deleteRequest)
      completion()
      print("Deleted entities")
    } catch let error as NSError {
      print("Error deleting!", error)
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
