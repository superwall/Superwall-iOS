//
//  Cache.swift
//  CacheDemo
//
//  Created by Nguyen Cong Huy on 7/4/16.
//  Copyright © 2016 Nguyen Cong Huy. All rights reserved.
//
import UIKit

enum ImageFormat {
  case unknown, png, jpeg
}

final class Cache {
  static let cacheDirectoryPrefix = "com.superwall.cache."
  static let ioQueuePrefix = "com.superwall.queue."
  static let defaultMaxCachePeriodInSecond: TimeInterval = 60 * 60 * 24 * 7 // a week

  static let instance = Cache(name: "default")

  let cachePath: String

  let memCache = NSCache<AnyObject, AnyObject>()
  let ioQueue: DispatchQueue
  let fileManager: FileManager

  /// Name of cache
  var name: String = ""

  /// Life time of disk cache, in second. Default is a week
  var maxCachePeriodInSecond = Cache.defaultMaxCachePeriodInSecond

  /// Size is allocated for disk cache, in byte. 0 mean no limit. Default is 0
  var maxDiskCacheSize: UInt = 0

  /// Specify distinc name param, it represents folder name for disk cache
  init(name: String, path: String? = nil) {
    self.name = name

    let defaultCacheDirectory = NSSearchPathForDirectoriesInDomains(
      .cachesDirectory,
      FileManager.SearchPathDomainMask.userDomainMask,
      true
    ).first!
    // swiftlint:disable:previous force_unwrapping

    var cachePath = path ?? defaultCacheDirectory
    cachePath = (cachePath as NSString).appendingPathComponent(Cache.cacheDirectoryPrefix + name)
    self.cachePath = cachePath

    ioQueue = DispatchQueue(label: Cache.ioQueuePrefix + name)

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

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

// MARK: - Store data
extension Cache {
  /// Write data for key. This is an async operation.
  func write(data: Data, forKey key: String) {
    memCache.setObject(data as AnyObject, forKey: key as AnyObject)
    writeDataToDisk(data: data, key: key)
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
          print("Cache: Error while creating cache folder: \(error.localizedDescription)")
        }
      }

      self.fileManager.createFile(atPath: self.cachePath(forKey: key), contents: data, attributes: nil)
    }
  }

  /// Read data for key
  func readData(forKey key: String) -> Data? {
    var data = memCache.object(forKey: key as AnyObject) as? Data

    if data == nil {
      if let dataFromDisk = readDataFromDisk(forKey: key) {
        data = dataFromDisk
        memCache.setObject(dataFromDisk as AnyObject, forKey: key as AnyObject)
      }
    }

    return data
  }

  /// Read data from disk for key
  func readDataFromDisk(forKey key: String) -> Data? {
    return self.fileManager.contents(atPath: cachePath(forKey: key))
  }

  // MARK: - Read & write Codable types
  func write<T: Encodable>(codable: T, forKey key: String) throws {
    let data = try JSONEncoder().encode(codable)
    write(data: data, forKey: key)
  }

  func readCodable<T: Decodable>(forKey key: String) throws -> T? {
    guard let data = readData(forKey: key) else { return nil }
    return try JSONDecoder().decode(T.self, from: data)
  }

  // MARK: - Read & write primitive types

  /// Write an object for key. This object must inherit from `NSObject` and implement `NSCoding` protocol. `String`, `Array`, `Dictionary` conform to this method.
  ///
  /// NOTE: Can't write `UIImage` with this method. Please use `writeImage(_:forKey:)` to write an image
  func write(object: NSCoding, forKey key: String) {
    let data = NSKeyedArchiver.archivedData(withRootObject: object)
    write(data: data, forKey: key)
  }

  /// Write a string for key
  func write(string: String, forKey key: String) {
    write(object: string as NSCoding, forKey: key)
  }

  /// Write a dictionary for key
  func write(dictionary: [AnyHashable: Any], forKey key: String) {
    write(object: dictionary as NSCoding, forKey: key)
  }

  /// Write an array for key
  func write(array: [Any], forKey key: String) {
    write(object: array as NSCoding, forKey: key)
  }

  /// Read an object for key. This object must inherit from `NSObject` and implement NSCoding protocol. `String`, `Array`, `Dictionary` conform to this method
  func readObject(forKey key: String) -> NSObject? {
    let data = readData(forKey: key)

    if let data = data {
      return NSKeyedUnarchiver.unarchiveObject(with: data) as? NSObject
    }

    return nil
  }

  /// Read a string for key
  func readString(forKey key: String) -> String? {
    return readObject(forKey: key) as? String
  }

  /// Read an array for key
  func readArray(forKey key: String) -> [Any]? {
    return readObject(forKey: key) as? [Any]
  }

  /// Read a dictionary for key
  func readDictionary(forKey key: String) -> [AnyHashable: Any]? {
    return readObject(forKey: key) as? [AnyHashable: Any]
  }

  // MARK: - Read & write image

  /// Write image for key. Please use this method to write an image instead of `writeObject(_:forKey:)`
  func write(image: UIImage, forKey key: String, format: ImageFormat? = nil) {
    var data: Data?

    if let format = format, format == .png {
      data = image.pngData()
    } else {
      data = image.jpegData(compressionQuality: 0.9)
    }

    if let data = data {
      write(data: data, forKey: key)
    }
  }

  /// Read image for key. Please use this method to write an image instead of `readObject(forKey:)`
  func readImage(forKey key: String) -> UIImage? {
    let data = readData(forKey: key)
    if let data = data {
      return UIImage(data: data, scale: 1.0)
    }

    return nil
  }

  @available(*, deprecated, message: "Please use `readImage(forKey:)` instead. This will be removed in the future.")
  func readImageForKey(key: String) -> UIImage? {
    return readImage(forKey: key)
  }
}

// MARK: - Utils
extension Cache {
  /// Check if has data for key
  func hasData(forKey key: String) -> Bool {
    return hasDataOnDisk(forKey: key) || hasDataOnMem(forKey: key)
  }

  /// Check if has data on disk
  func hasDataOnDisk(forKey key: String) -> Bool {
    return self.fileManager.fileExists(atPath: self.cachePath(forKey: key))
  }

  /// Check if has data on mem
  func hasDataOnMem(forKey key: String) -> Bool {
    return (memCache.object(forKey: key as AnyObject) != nil)
  }
}

// MARK: - Clean
extension Cache {
  /// Clean all mem cache and disk cache. This is an async operation.
  func cleanAll() {
    cleanMemCache()
    cleanDiskCache()
  }

  /// Clean cache by key. This is an async operation.
  func clean(byKey key: String) {
    memCache.removeObject(forKey: key as AnyObject)

    ioQueue.async {
      do {
        try self.fileManager.removeItem(atPath: self.cachePath(forKey: key))
      } catch {
        print("Cache: Error while remove file: \(error.localizedDescription)")
      }
    }
  }

  func cleanMemCache() {
    memCache.removeAllObjects()
  }

  func cleanDiskCache() {
    ioQueue.async {
      do {
        try self.fileManager.removeItem(atPath: self.cachePath)
      } catch {
        print("Cache: Error when clean disk: \(error.localizedDescription)")
      }
    }
  }

  /// Clean expired disk cache. This is an async operation.
  @objc func cleanExpiredDiskCache() {
    cleanExpiredDiskCache(completion: nil)
  }

  // This method is from Kingfisher
  /**
    Clean expired disk cache. This is an async operation.

    - parameter completionHandler: Called after the operation completes.
  */
  func cleanExpiredDiskCache(completion handler: (() -> Void)? = nil) {
    // Do things in cocurrent io queue
    ioQueue.async {
      var (URLsToDelete, diskCacheSize, cachedFiles) = self.travelCachedFiles(onlyForCacheSize: false)

      for fileURL in URLsToDelete {
        do {
          try self.fileManager.removeItem(at: fileURL)
        } catch {
          print("Cache: Error while removing files \(error.localizedDescription)")
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
            print("Cache: Error while removing files \(error.localizedDescription)")
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

      DispatchQueue.main.async {
        handler?()
      }
    }
  }
}

// MARK: - Helpers
extension Cache {
  // This method is from Kingfisher
  // swiftlint:disable all
  fileprivate func travelCachedFiles(
    onlyForCacheSize: Bool
  ) -> (urlsToDelete: [URL], diskCacheSize: UInt, cachedFiles: [URL: URLResourceValues]) {
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
          if !onlyForCacheSize,
            let expiredDate = expiredDate,
            let lastAccessData = resourceValues.contentAccessDate,
            (lastAccessData as NSDate).laterDate(expiredDate) == expiredDate {
            urlsToDelete.append(fileUrl)
            continue
          }

          if let fileSize = resourceValues.totalFileAllocatedSize {
            diskCacheSize += UInt(fileSize)
            if !onlyForCacheSize {
              cachedFiles[fileUrl] = resourceValues
            }
          }
      } catch {
        print("Cache: Error while iterating files \(error.localizedDescription)")
      }
    }

    return (urlsToDelete, diskCacheSize, cachedFiles)
  }

  func cachePath(forKey key: String) -> String {
    let fileName = key.md5
    return (cachePath as NSString).appendingPathComponent(fileName)
  }
}


protocol Cachable: Codable {
  var cacheName: String { get }
}
