//
//  Cache.swift
//  CacheDemo
//
//  Created by Nguyen Cong Huy on 7/4/16.
//  Copyright © 2016 Nguyen Cong Huy. All rights reserved.
//
// swiftlint:disable file_length large_tuple type_body_length

import UIKit

class Cache {
  static let userSpecificDocumentDirectoryPrefix = "com.superwall.document.userSpecific.Store"
  static let appSpecificDocumentDirectoryPrefix = "com.superwall.document.appSpecific.Store"
  private static let cacheDirectoryPrefix = "com.superwall.cache.Store"
  private static let ioQueuePrefix = "com.superwall.queue.Store"
  private static let defaultMaxCachePeriodInSecond: TimeInterval = 60 * 60 * 24 * 7 // a week
  private let cacheUrl: URL?
  private let userSpecificDocumentUrl: URL?
  private let appSpecificDocumentUrl: URL?
  private let memCache = NSCache<AnyObject, AnyObject>()
  private let ioQueue: DispatchQueue
  private let fileManager: FileManager

  /// Life time of disk cache, in second. Default is a week
  private var maxCachePeriodInSecond = Cache.defaultMaxCachePeriodInSecond

  /// Size is allocated for disk cache, in byte. 0 mean no limit. Default is 0
  private var maxDiskCacheSize: UInt = 0

  /// Specify distinct name param, it represents folder name for disk cache
  init(
    fileManager: FileManager = FileManager(),
    ioQueue: DispatchQueue = DispatchQueue(label: Cache.ioQueuePrefix)
  ) {
    self.fileManager = fileManager
    cacheUrl = fileManager
      .urls(for: .cachesDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent(Cache.cacheDirectoryPrefix)
    userSpecificDocumentUrl = fileManager
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent(Cache.userSpecificDocumentDirectoryPrefix)
    appSpecificDocumentUrl = fileManager
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent(Cache.appSpecificDocumentDirectoryPrefix)

    self.ioQueue = ioQueue

    #if !os(OSX) && !os(watchOS)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(cleanExpiredDiskCache),
        name: UIApplication.willTerminateNotification,
        object: nil
      )
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(cleanExpiredDiskCache),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
      )
    #endif
  }

  // MARK: - Migrate
  func moveDataFromDocumentsToApplicationSupport() {
    ioQueue.async { [weak self] in
      guard let self = self else { return }
      guard
        let documentDirectory = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
        let applicationSupportDirectory = self.fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      else {
        return
      }

      let userSpecificDocumentUrl = documentDirectory.appendingPathComponent(Cache.userSpecificDocumentDirectoryPrefix)
      let appSpecificDocumentUrl = documentDirectory.appendingPathComponent(Cache.appSpecificDocumentDirectoryPrefix)

      let userSpecificSupportUrl = applicationSupportDirectory.appendingPathComponent(Cache.userSpecificDocumentDirectoryPrefix)
      let appSpecificSupportUrl = applicationSupportDirectory.appendingPathComponent(Cache.appSpecificDocumentDirectoryPrefix)

      do {
        // Create the destination directories if they don't exist.
        try self.createDirectoryIfNeeded(at: userSpecificSupportUrl)
        try self.createDirectoryIfNeeded(at: appSpecificSupportUrl)

        // Move user-specific data by enumerating individual items.
        try self.moveItems(
          from: userSpecificDocumentUrl,
          to: userSpecificSupportUrl,
          notFoundMessage: "No user-specific data found at \(userSpecificDocumentUrl.path)"
        )

        // Remove the user-specific folder if empty
        try self.removeDirectoryIfEmpty(userSpecificDocumentUrl)

        // Move app-specific data by enumerating individual items.
        try self.moveItems(
          from: appSpecificDocumentUrl,
          to: appSpecificSupportUrl,
          notFoundMessage: "No app-specific data found at \(appSpecificDocumentUrl.path)")

        // Remove the app-specific folder if empty
        try self.removeDirectoryIfEmpty(appSpecificDocumentUrl)
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .cache,
          message: "Migration of document data failed: \(error.localizedDescription)"
        )
      }
    }
  }

  private func createDirectoryIfNeeded(at url: URL) throws {
    if !self.fileManager.fileExists(atPath: url.path) {
      try self.fileManager.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
  }

  private func moveItems(from sourceDirectory: URL, to destinationDirectory: URL, notFoundMessage: String) throws {
    if self.fileManager.fileExists(atPath: sourceDirectory.path) {
      let items = try self.fileManager.contentsOfDirectory(atPath: sourceDirectory.path)
      for item in items {
        let sourceURL = sourceDirectory.appendingPathComponent(item)
        let destinationURL = destinationDirectory.appendingPathComponent(item)
        // Remove item if the file/directory already exists at the destination.
        if self.fileManager.fileExists(atPath: destinationURL.path) {
          try self.fileManager.removeItem(at: destinationURL)
        }
        try self.fileManager.moveItem(
          at: sourceURL,
          to: destinationURL
        )
      }
    } else {
      Logger.debug(
        logLevel: .debug,
        scope: .cache,
        message: notFoundMessage
      )
    }
  }

  private func removeDirectoryIfEmpty(_ directory: URL) throws {
    if let contents = try? self.fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: []
    ), contents.isEmpty {
      try self.fileManager.removeItem(at: directory)
    }
  }

  // MARK: - Store data
  /// Read data for key
  func read<Key: Storable>(
    _ keyType: Key.Type,
    fromDirectory directory: SearchPathDirectory? = nil
  ) -> Key.Value? where Key.Value: Decodable {
    var data = memCache.object(forKey: keyType.key as AnyObject) as? Data

    if data == nil {
      ioQueue.sync {
        let directory = directory ?? keyType.directory
        if let path = cachePath(forKey: keyType.key, directory: directory),
          let dataFromDisk = fileManager.contents(atPath: path) {
          data = dataFromDisk
          memCache.setObject(dataFromDisk as AnyObject, forKey: keyType.key as AnyObject)
        }
      }
    }
    guard let data = data else {
      return nil
    }

    guard let data = NSKeyedUnarchiver.unarchiveObject(with: data) as? Data else {
      return nil
    }
    do {
      return try JSONDecoder().decode(Key.Value.self, from: data)
    } catch {
      return nil
    }
  }

  /// Read data for key
  func read<Key: Storable>(
    _ keyType: Key.Type,
    fromDirectory directory: SearchPathDirectory? = nil
  ) -> Key.Value? {
    var data = memCache.object(forKey: keyType.key as AnyObject) as? Data
    let directory = directory ?? keyType.directory

    if let path = cachePath(forKey: keyType.key, directory: directory),
      data == nil {
      ioQueue.sync {
        if let dataFromDisk = fileManager.contents(atPath: path) {
          data = dataFromDisk
          memCache.setObject(dataFromDisk as AnyObject, forKey: keyType.key as AnyObject)
        }
      }
    }

    if let data = data {
      return NSKeyedUnarchiver.unarchiveObject(with: data) as? Key.Value
    }
    return nil
  }

  func delete<Key: Storable>(
    _ keyType: Key.Type,
    fromDirectory directory: SearchPathDirectory? = nil
  ) {
    memCache.removeObject(forKey: keyType.key as AnyObject)
    deleteDataFromDisk(
      withKey: keyType.key,
      fromDirectory: directory ?? keyType.directory
    )
  }

  /// Write data for key. This is an async operation.
  ///
  /// - Parameters:
  ///   - value: The data to write.
  ///   - keyType: The `Storable` type that you want to store.
  ///   - directory: The directory that you want to save to. This should only be used when migrating data, for all other instances, leave this as `nil` to fallback to the directory specified by the type.
  func write<Key: Storable>(
    _ value: Key.Value,
    forType keyType: Key.Type,
    inDirectory directory: SearchPathDirectory? = nil
  ) {
    guard let value = value as? NSCoding else {
      return
    }

    guard let data = try? NSKeyedArchiver.archivedData(
      withRootObject: value,
      requiringSecureCoding: true
    ) else {
      Logger.debug(
        logLevel: .warn,
        scope: .cache,
        message: "Could not write object that doesn't conform to NSSecureCoding to cache."
      )
      return
    }
    memCache.setObject(data as AnyObject, forKey: keyType.key as AnyObject)

    writeDataToDisk(
      data: data,
      key: keyType.key,
      toDirectory: directory ?? keyType.directory
    )
  }

  /// Write data for key. This is an async operation.
  /// - Parameters:
  ///   - value: The data to write.
  ///   - keyType: The `Storable` type that you want to store.
  ///   - directory: The directory that you want to save to. This should only be used when migrating data, for all other instances, leave this as `nil` to fallback to the directory specified by the type.
  func write<Key: Storable>(
    _ value: Key.Value,
    forType keyType: Key.Type,
    inDirectory directory: SearchPathDirectory? = nil
  ) where Key.Value: Encodable {
    guard let data = try? JSONEncoder().encode(value) else {
      return
    }

    guard let archivedData = try? NSKeyedArchiver.archivedData(
      withRootObject: data,
      requiringSecureCoding: true
    ) else {
      Logger.debug(
        logLevel: .warn,
        scope: .cache,
        message: "Could not write object that doesn't conform to NSSecureCoding to cache."
      )
      return
    }
    memCache.setObject(archivedData as AnyObject, forKey: keyType.key as AnyObject)

    writeDataToDisk(
      data: archivedData,
      key: keyType.key,
      toDirectory: directory ?? keyType.directory
    )
  }

  private func writeDataToDisk(
    data: Data,
    key: String,
    toDirectory directory: SearchPathDirectory
  ) {
    ioQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      if let directoryUrl = self.getDirectoryUrl(from: directory),
        self.fileManager.fileExists(atPath: directoryUrl.path) == false {
        do {
          try self.fileManager.createDirectory(
            atPath: directoryUrl.path,
            withIntermediateDirectories: true,
            attributes: nil
          )
        } catch {
          Logger.debug(
            logLevel: .error,
            scope: .cache,
            message: "Error while creating cache folder: \(error.safeLocalizedDescription)"
          )
        }
      }

      if let path = self.cachePath(
        forKey: key,
        directory: directory
      ) {
        self.fileManager.createFile(
          atPath: path,
          contents: data
        )
      }
    }
  }

  private func deleteDataFromDisk(
    withKey key: String,
    fromDirectory directory: SearchPathDirectory
  ) {
    ioQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      do {
        if let path = self.cachePath(
          forKey: key,
          directory: directory
        ) {
          if self.fileManager.fileExists(atPath: path) {
            try self.fileManager.removeItem(atPath: path)
          }
        }
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .cache,
          message: "Error while deleting file: \(error.safeLocalizedDescription)"
        )
      }
    }
  }
}

// MARK: - Clean
extension Cache {
  /// Clean all mem cache and disk cache. This is an async operation.
  func cleanUserFiles() {
    memCache.removeAllObjects()
    cleanDiskCache()
  }

  /// Cleans codes and entitlements that are owned by the user.
  func cleanUserCodes() {
    if let redeemResponse = read(LatestRedeemResponse.self) {
      let existingWebEntitlements = redeemResponse.entitlements
      var deviceResults: [RedemptionResult] = []

      for result in redeemResponse.results {
        switch result {
        case .success(_, let redemptionInfo):
          if case .device = redemptionInfo.ownership {
            deviceResults.append(result)
          }
        case .expiredSubscription(_, let redemptionInfo):
          if case .device = redemptionInfo.ownership {
            deviceResults.append(result)
          }
        default:
          break
        }
      }

      let newRedeemResponse = RedeemResponse(
        results: deviceResults,
        entitlements: []
      )

      write(newRedeemResponse, forType: LatestRedeemResponse.self)

      if !existingWebEntitlements.isEmpty {
        let deviceEntitlements = Superwall.shared.entitlements.activeDeviceEntitlements
        Task {
          await Superwall.shared.internallySetSubscriptionStatus(to: .active(deviceEntitlements))
        }
      }
    }
  }

  private func cleanDiskCache() {
    ioQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      do {
        if let path = self.cacheUrl?.path,
          self.fileManager.fileExists(atPath: path) {
          try self.fileManager.removeItem(atPath: path)
        }
        if let path = self.userSpecificDocumentUrl?.path,
          self.fileManager.fileExists(atPath: path) {
          try self.fileManager.removeItem(atPath: path)
        }
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .cache,
          message: "Error when clean disk: \(error.safeLocalizedDescription)"
        )
      }
    }
  }

  // This method is from Kingfisher
  /**
    Clean expired disk cache. This is an async operation.

    - parameter completionHandler: Called after the operation completes.
  */
  @objc private func cleanExpiredDiskCache() {
    // Do things in cocurrent io queue
    ioQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      var (URLsToDelete, diskCacheSize, cachedFiles) = self.travelCachedFiles()

      for fileURL in URLsToDelete {
        do {
          try self.fileManager.removeItem(at: fileURL)
        } catch {
          Logger.debug(
            logLevel: .error,
            scope: .cache,
            message: "Error while removing files \(error.safeLocalizedDescription)"
          )
        }
      }

      if self.maxDiskCacheSize > 0 && diskCacheSize > self.maxDiskCacheSize {
        let targetSize = self.maxDiskCacheSize / 2

        // Sort files by last modify date. We want to clean from the oldest files.
        let sortedFiles = cachedFiles.keysSortedByValue { resourceValue1, resourceValue2 -> Bool in
          if let date1 = resourceValue1.contentAccessDate,
            let date2 = resourceValue2.contentAccessDate {
            return date1.compare(date2) == .orderedAscending
          }

          // Not valid date information. This should not happen. Just in case.
          return true
        }

        for fileURL in sortedFiles {
          do {
            try self.fileManager.removeItem(at: fileURL)
          } catch {
            Logger.debug(
              logLevel: .error,
              scope: .cache,
              message: "Error while removing files \(error.safeLocalizedDescription)"
            )
          }

          URLsToDelete.append(fileURL)

          if let fileSize = cachedFiles[fileURL]?.totalFileAllocatedSize {
            diskCacheSize -= UInt(fileSize)
          }

          if diskCacheSize < targetSize {
            break
          }
        }
      }
    }
  }
}

// MARK: - Helpers
extension Cache {
  // This method is from Kingfisher
  private func travelCachedFiles() -> (urlsToDelete: [URL], diskCacheSize: UInt, cachedFiles: [URL: URLResourceValues]) {
    let resourceKeys: Set<URLResourceKey> = [
      .isDirectoryKey,
      .contentAccessDateKey,
      .totalFileAllocatedSizeKey
    ]

    let maxCachePeriodIsInPast = maxCachePeriodInSecond < 0
    let expiredDate = maxCachePeriodIsInPast ? nil : Date(timeIntervalSinceNow: -maxCachePeriodInSecond)

    var cachedFiles: [URL: URLResourceValues] = [:]
    var urlsToDelete: [URL] = []
    var diskCacheSize: UInt = 0
    var directoryContents: [URL]?

    if let cacheUrl = cacheUrl {
      directoryContents = try? fileManager.contentsOfDirectory(
        at: cacheUrl,
        includingPropertiesForKeys: Array(resourceKeys),
        options: .skipsHiddenFiles
      )
    }

    for fileUrl in directoryContents ?? [] {
      do {
        let resourceValues = try fileUrl.resourceValues(forKeys: resourceKeys)
        // If it is a Directory. Continue to next file URL.
        if resourceValues.isDirectory == true {
          continue
        }

        // If this file is expired and not recently accessed, add it to URLsToDelete
        if let expiredDate = expiredDate,
          let lastAccessData = resourceValues.contentAccessDate,
          (lastAccessData as NSDate).laterDate(expiredDate) == expiredDate {
          urlsToDelete.append(fileUrl)
          continue
        }

        if let fileSize = resourceValues.totalFileAllocatedSize {
          diskCacheSize += UInt(fileSize)
          cachedFiles[fileUrl] = resourceValues
        }
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .cache,
          message: "Error while iterating files \(error.safeLocalizedDescription)"
        )
      }
    }

    return (urlsToDelete, diskCacheSize, cachedFiles)
  }

  func cachePath(
    forKey key: String,
    directory: SearchPathDirectory
  ) -> String? {
    let fileName = key.md5
    let directoryUrl = getDirectoryUrl(from: directory)
    return directoryUrl?.appendingPathComponent(fileName).path
  }

  private func getDirectoryUrl(from directory: SearchPathDirectory) -> URL? {
    switch directory {
    case .cache:
      return cacheUrl
    case .userSpecificDocuments:
      return userSpecificDocumentUrl
    case .appSpecificDocuments:
      return appSpecificDocumentUrl
    }
  }
}
