//
//  DeviceIPCollector.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 15/09/2026.
//

import Foundation
import Darwin

/// Best-effort, session-local observations. Never waits on the network when reading attributes.
actor DeviceIPCollector {
  typealias Fetch = () async throws -> [String: String]

  /// One address lookup with its own schedule, so a failing IPv6 lookup
  /// doesn't hold up or speed up the IPv4 one.
  private struct Lookup {
    let name: String
    /// 4 or 6, or `nil` for a test lookup that only runs when every lookup is asked for.
    let family: Int?
    let fetch: Fetch
    var lastAttempt: Date?
    var nextAttemptAt: Date?

    init(name: String, family: Int?, fetch: @escaping Fetch) {
      self.name = name
      self.family = family
      self.fetch = fetch
    }
  }

  private var lookups: [Lookup]
  private let now: () -> Date
  private var observations: [String: String] = [:]
  /// Whether an IPv6 address has been seen this session. Kept after that
  /// address goes stale, since enrichment may not run again this session.
  private var hasSeenIPv6 = false
  private let lifetime: TimeInterval = 15 * 60
  /// How long to wait after a failed fetch. Shorter than `lifetime` so a
  /// blip is retried soon, but long enough that an outage or offline device
  /// doesn't send a request on every read of the device attributes.
  private let retryDelay: TimeInterval = 60

  /// - Parameters:
  ///   - ipV4Url: An IPv4-only endpoint to ask. When `nil`, IPv4 isn't looked up.
  ///   - ipV6Url: An endpoint to ask over IPv6 only. When `nil`, on watchOS, or
  ///     on systems that can't require IPv6, IPv6 isn't looked up.
  init(
    ipV4Url: URL?,
    ipV6Url: URL?,
    now: @escaping () -> Date = Date.init
  ) {
    var lookups: [Lookup] = []
    if let ipV4Url = ipV4Url {
      lookups.append(Lookup(name: "IPv4", family: 4) { try await Self.fetchIPv4(from: ipV4Url) })
    }
    // watchOS doesn't let apps open their own connections like this.
    #if canImport(Network) && !os(watchOS)
    if let ipV6Url = ipV6Url,
      #available(iOS 12.0, macOS 10.14, tvOS 12.0, watchOS 6.0, *) {
      lookups.append(Lookup(name: "IPv6", family: 6) { try await Self.fetchOverIPv6(from: ipV6Url) })
    }
    #endif
    self.lookups = lookups
    self.now = now
  }

  /// One lookup per closure, each with its own schedule. For tests.
  init(
    fetches: [Fetch],
    now: @escaping () -> Date = Date.init
  ) {
    self.lookups = fetches.enumerated().map {
      Lookup(name: "test \($0.offset)", family: nil, fetch: $0.element)
    }
    self.now = now
  }

  /// One lookup per address family. For tests.
  init(
    ipV4Fetch: @escaping Fetch,
    ipV6Fetch: @escaping Fetch,
    now: @escaping () -> Date = Date.init
  ) {
    self.lookups = [
      Lookup(name: "IPv4", family: 4, fetch: ipV4Fetch),
      Lookup(name: "IPv6", family: 6, fetch: ipV6Fetch)
    ]
    self.now = now
  }

  /// Starts any lookups that are due, in the background. The returned task
  /// finishes when they do and is only there so tests can wait for it.
  ///
  /// - Parameter families: The address families to look up, or `nil` for all of them.
  @discardableResult
  func refreshIfNeeded(families: Set<Int>? = nil) -> Task<Void, Never>? {
    let date = now()
    var started: [Task<Void, Never>] = []
    for index in lookups.indices {
      if let families = families,
        !families.contains(lookups[index].family ?? 0) {
        continue
      }
      if let nextAttemptAt = lookups[index].nextAttemptAt,
        date < nextAttemptAt {
        continue
      }
      lookups[index].lastAttempt = date
      lookups[index].nextAttemptAt = date.addingTimeInterval(lifetime)
      started.append(start(lookupAt: index, attemptedAt: date))
    }
    if started.isEmpty {
      return nil
    }
    return Task {
      for task in started {
        await task.value
      }
    }
  }

  private func start(lookupAt index: Int, attemptedAt date: Date) -> Task<Void, Never> {
    let lookup = lookups[index]
    return Task {
      do {
        record(try await lookup.fetch())
      } catch {
        // Try again sooner than a success would, unless a newer attempt started.
        if lookups[index].lastAttempt == date {
          lookups[index].nextAttemptAt = date.addingTimeInterval(retryDelay)
        }
        Logger.debug(
          logLevel: .debug,
          scope: .network,
          message: "Couldn't fetch the device's \(lookup.name) address",
          error: error
        )
      }
    }
  }

  func record(_ device: [String: String]) {
    for family in [4, 6] {
      let key = "ipV\(family)"
      // Each address only counts with its own timestamp, so an `ipV6` with no
      // time can't borrow the time of an IPv4 `ipAddress`.
      let address: String?
      let timestamp: String?
      if let familyAddress = device[key] {
        address = familyAddress
        timestamp = device["\(key)ObservedAt"]
      } else {
        address = device["ipAddress"]
        timestamp = device["ipAddressObservedAt"]
      }
      guard
        let address = address,
        let timestamp = timestamp,
        let date = Self.date(from: timestamp),
        Self.isValid(address, family: family),
        isFresh(date)
      else {
        continue
      }
      if let previous = observations["\(key)ObservedAt"],
        let previousDate = Self.date(from: previous),
        previousDate > date {
        continue
      }
      observations[key] = address
      observations["\(key)ObservedAt"] = timestamp
      if family == 6 {
        hasSeenIPv6 = true
      }
    }
  }

  /// Starts the IPv4 lookup only when the device has been on IPv6 this session
  /// and no fresh IPv4 address is known. On an IPv4 network the device's own
  /// requests already show its IPv4 address, so there's nothing to look up.
  @discardableResult
  func refreshIPv4IfOnlyIPv6IsKnown() -> Task<Void, Never>? {
    if !hasSeenIPv6 || hasFreshObservation(family: 4) {
      return nil
    }
    return refreshIfNeeded(families: [4])
  }

  func attributes(families: Set<Int> = [4, 6]) -> [String: String] {
    var result: [String: String] = [:]
    for family in families.sorted() where hasFreshObservation(family: family) {
      let key = "ipV\(family)"
      result[key] = observations[key]
      result["\(key)ObservedAt"] = observations["\(key)ObservedAt"]
    }
    return result
  }

  private func hasFreshObservation(family: Int) -> Bool {
    guard
      let timestamp = observations["ipV\(family)ObservedAt"],
      let date = Self.date(from: timestamp)
    else {
      return false
    }
    return isFresh(date)
  }

  private func isFresh(_ date: Date) -> Bool {
    let age = now().timeIntervalSince(date)
    return age >= -60 && age < lifetime
  }

  static func isValid(_ address: String, family: Int) -> Bool {
    if family == 4 {
      var bytes = in_addr()
      return inet_pton(AF_INET, address, &bytes) == 1
    }
    var bytes = in6_addr()
    return inet_pton(AF_INET6, address, &bytes) == 1 && !address.lowercased().hasPrefix("::ffff:")
  }

  private static let fractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let wholeSecondFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  /// Parses ISO 8601 timestamps with or without milliseconds.
  static func date(from timestamp: String) -> Date? {
    return fractionalFormatter.date(from: timestamp)
      ?? wholeSecondFormatter.date(from: timestamp)
  }

  static func fetchIPv4(from url: URL) async throws -> [String: String] {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 3
    config.timeoutIntervalForResource = 3
    let session = URLSession(configuration: config)
    defer { session.finishTasksAndInvalidate() }
    let data: Data = try await withCheckedThrowingContinuation { continuation in
      let task = session.dataTask(with: url) { data, response, error in
        if let error = error {
          continuation.resume(throwing: error)
          return
        }
        guard
          let response = response as? HTTPURLResponse,
          response.statusCode == 200,
          let data = data,
          data.count < 16_384
        else {
          continuation.resume(throwing: URLError(.badServerResponse))
          return
        }
        continuation.resume(returning: data)
      }
      task.resume()
    }
    return try parseDevice(from: data)
  }

  /// Reads the string values of the response's `device` object, skipping any
  /// that aren't strings.
  static func parseDevice(from data: Data) throws -> [String: String] {
    guard
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let device = json["device"] as? [String: Any]
    else {
      throw URLError(.cannotParseResponse)
    }
    return device.compactMapValues { $0 as? String }
  }
}
