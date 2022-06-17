//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/06/2022.
//
// swiftlint:disable force_unwrapping

import Foundation
import CoreData

final class ManagedEvent: NSManagedObject {
  @nonobjc
  class func fetchRequest() -> NSFetchRequest<ManagedEvent> {
    return NSFetchRequest<ManagedEvent>(entityName: "Event")
  }

  @NSManaged private(set) var name: String
  @NSManaged var data: NSOrderedSet?

  init(
    context: NSManagedObjectContext,
    name: String,
    data: NSOrderedSet? = nil
  ) {
    let entity = NSEntityDescription.entity(
      forEntityName: "Event",
      in: context
    )!
    super.init(entity: entity, insertInto: context)
    self.name = name
    self.data = data
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

  @objc(insertObject:inDataAtIndex:)
  @NSManaged func insertIntoData(_ value: ManagedEventData, at idx: Int)

  @objc(removeObjectFromDataAtIndex:)
  @NSManaged func removeFromData(at idx: Int)

  @objc(insertData:atIndexes:)
  @NSManaged func insertIntoData(_ values: [ManagedEventData], at indexes: NSIndexSet)

  @objc(removeDataAtIndexes:)
  @NSManaged func removeFromData(at indexes: NSIndexSet)

  @objc(replaceObjectInDataAtIndex:withObject:)
  @NSManaged func replaceData(at idx: Int, with value: ManagedEventData)

  @objc(replaceDataAtIndexes:withData:)
  @NSManaged func replaceData(at indexes: NSIndexSet, with values: [ManagedEventData])

  @objc(addDataObject:)
  @NSManaged func addToData(_ value: ManagedEventData)

  @objc(removeDataObject:)
  @NSManaged func removeFromData(_ value: ManagedEventData)

  @objc(addData:)
  @NSManaged func addToData(_ values: NSOrderedSet)

  @objc(removeData:)
  @NSManaged func removeFromData(_ values: NSOrderedSet)
}
