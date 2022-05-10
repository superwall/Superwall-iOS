//
//  Cache.swift
//  CacheDemo
//
//  Created by Nguyen Cong Huy on 7/4/16.
//  Copyright © 2016 Nguyen Cong Huy. All rights reserved.
//
import UIKit

final class Cache {
  private static let cacheDirectoryPrefix = "com.superwall.cache.Store"
  private static let ioQueuePrefix = "com.superwall.queue.Store"
  private static let defaultMaxCachePeriodInSecond: TimeInterval = 60 * 60 * 24 * 7 // a week
  private let cachePath: String
  private let memCache = NSCache<AnyObject, AnyObject>()
  private let ioQueue: DispatchQueue
  private let fileManager: FileManager

  /// Life time of disk cache, in second. Default is a week
  private var maxCachePeriodInSecond = Cache.defaultMaxCachePeriodInSecond

  /// Size is allocated for disk cache, in byte. 0 mean no limit. Default is 0
  private var maxDiskCacheSize: UInt = 0

  /// Specify distinc name param, it represents folder name for disk cache
  init(ioQueue: DispatchQueue = DispatchQueue(label: Cache.ioQueuePrefix)) {
    var cachePath = NSSearchPathForDirectoriesInDomains(
      .cachesDirectory,
      FileManager.SearchPathDomainMask.userDomainMask,
      true
    ).first!
    // swiftlint:disable:previous force_unwrapping

    cachePath = (cachePath as NSString).appendingPathComponent(Cache.cacheDirectoryPrefix)
    self.cachePath = cachePath

    self.ioQueue = ioQueue

    self.fileManager = FileManager()

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
}

// MARK: - Store data
extension Cache {
  /// Read data for key
  func read<Key: CachingType>(
    _ keyType: Key.Type
  ) -> Key.Value? {
    var data = memCache.object(forKey: keyType.key as AnyObject) as? Data
    if data == nil,
      let dataFromDisk = fileManager.contents(atPath: cachePath(forKey: keyType.key)) {
      data = dataFromDisk
      memCache.setObject(dataFromDisk as AnyObject, forKey: keyType.key as AnyObject)
    }

    if let data = data {
      return NSKeyedUnarchiver.unarchiveObject(with: data) as? Key.Value
    }
    return nil
  }

  /// Write data for key. This is an async operation.
  func write<Key: CachingType>(
    _ value: Key.Value,
    forType keyType: Key.Type
  ) {
    guard let value = value as? NSCoding else {
      return
    }
    let data = NSKeyedArchiver.archivedData(withRootObject: value)

    memCache.setObject(data as AnyObject, forKey: keyType.key as AnyObject)
    writeDataToDisk(data: data, key: keyType.key)
  }

  private func writeDataToDisk(data: Data, key: String) {
    ioQueue.async {
      if self.fileManager.fileExists(atPath: self.cachePath) == false {
        do {
          try self.fileManager.createDirectory(
            atPath: self.cachePath,
            withIntermediateDirectories: true,
            attributes: nil
          )
        } catch {
          Logger.debug(
            logLevel: .error,
            scope: .cache,
            message: "Error while creating cache folder: \(error.localizedDescription)"
          )
        }
      }

      self.fileManager.createFile(atPath: self.cachePath(forKey: key), contents: data, attributes: nil)
    }
  }
}

// MARK: - Clean
extension Cache {
  /// Clean all mem cache and disk cache. This is an async operation.
  func cleanAll() {
    cleanMemCache()
    cleanDiskCache()
  }

  private func cleanMemCache() {
    memCache.removeAllObjects()
  }

  private func cleanDiskCache() {
    ioQueue.async {
      do {
        try self.fileManager.removeItem(atPath: self.cachePath)
      } catch {
        Logger.debug(
          logLevel: .error,
          scope: .cache,
          message: "Error when clean disk: \(error.localizedDescription)"
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
    ioQueue.async {
      var (URLsToDelete, diskCacheSize, cachedFiles) = self.travelCachedFiles()

      for fileURL in URLsToDelete {
        do {
          try self.fileManager.removeItem(at: fileURL)
        } catch {
          Logger.debug(
            logLevel: .error,
            scope: .cache,
            message: "Error while removing files \(error.localizedDescription)"
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
              message: "Error while removing files \(error.localizedDescription)"
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
  // swiftlint:disable all
  fileprivate func travelCachedFiles() -> (urlsToDelete: [URL], diskCacheSize: UInt, cachedFiles: [URL: URLResourceValues]) {
    let diskCacheURL = URL(fileURLWithPath: cachePath)
    let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentAccessDateKey, .totalFileAllocatedSizeKey]
    let expiredDate: Date? = (maxCachePeriodInSecond < 0) ? nil : Date(timeIntervalSinceNow: -maxCachePeriodInSecond)

    var cachedFiles: [URL: URLResourceValues] = [:]
    var urlsToDelete: [URL] = []
    var diskCacheSize: UInt = 0

    for fileUrl in (try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)) ?? [] {
        do {
          let resourceValues = try fileUrl.resourceValues(forKeys: resourceKeys)
          // If it is a Directory. Continue to next file URL.
          if resourceValues.isDirectory == true {
              continue
          }

          // If this file is expired, add it to URLsToDelete
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
          message: "Error while iterating files \(error.localizedDescription)"
        )
      }
    }

    return (urlsToDelete, diskCacheSize, cachedFiles)
  }

  func cachePath(forKey key: String) -> String {
    let fileName = key.md5
    return (cachePath as NSString).appendingPathComponent(fileName)
  }
}
