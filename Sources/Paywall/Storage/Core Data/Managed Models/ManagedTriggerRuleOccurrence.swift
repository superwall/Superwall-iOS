//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation
import CoreData

final class ManagedTriggerRuleOccurrence: NSManagedObject {
  static let entityName = "TriggerRuleOccurrence"
  @NSManaged var createdAt: Date
  @NSManaged var occurrenceKey: String

  init?(
    context: NSManagedObjectContext,
    createdAt: Date,
    occurrenceKey: String
  ) {
    guard let entity = NSEntityDescription.entity(
      forEntityName: Self.entityName,
      in: context
    ) else {
      Logger.debug(
        logLevel: .error,
        scope: .coreData,
        message: "Failed to create managed trigger rule occurrence for key: \(occurrenceKey)"
      )
      return nil
    }
    super.init(entity: entity, insertInto: context)

    self.createdAt = createdAt
    self.occurrenceKey = occurrenceKey
  }

  @nonobjc
  class func fetchRequest() -> NSFetchRequest<ManagedTriggerRuleOccurrence> {
    return NSFetchRequest<ManagedTriggerRuleOccurrence>(entityName: entityName)
  }

  @objc override private init(
    entity: NSEntityDescription,
    insertInto context: NSManagedObjectContext?
  ) {
    super.init(entity: entity, insertInto: context)
  }

  @available(*, unavailable)
  init() {
    fatalError("\(#function) not implemented")
  }

  @available(*, unavailable)
  convenience init(context: NSManagedObjectContext) {
    fatalError("\(#function) not implemented")
  }
}
