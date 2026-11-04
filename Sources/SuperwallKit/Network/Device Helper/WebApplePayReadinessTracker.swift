//
//  WebApplePayReadinessTracker.swift
//  SuperwallKit
//
//  Created by Jake Mor on 04/11/2026.
//

import Foundation

/// A stored `ready` or `notReady` answer, with the origin it was measured at.
/// The Apple Pay merchant is derived from the checkout's hostname, so an answer
/// measured at one origin says nothing about another.
struct WebApplePayMeasurement: Codable, Equatable {
  let origin: String
  let readiness: String
  let measuredAt: Date
}

/// Keeps the `webApplePayReadiness` device attribute.
///
/// Reads never block. The last measurement is stored and served at once on the
/// next launch, and one refresh runs in the background per launch, so a value is
/// at most one launch stale. A probe that measures nothing (`unknown`) never
/// replaces a stored answer.
///
/// The one wait is for audience rules on a device that has never been measured:
/// see ``waitForFirstMeasurement(at:budget:)``.
actor WebApplePayReadinessTracker {
  typealias Measure = @MainActor (URL) async -> WebApplePayProbe.Outcome

  /// How long audience evaluation may be held for a first measurement, counted
  /// from when the probe started rather than per evaluation, so a launch pays it
  /// at most once.
  static let firstMeasurementBudget: TimeInterval = 2

  private let measure: Measure
  private let save: (WebApplePayMeasurement) -> Void
  private let now: () -> Date
  private var stored: WebApplePayMeasurement?
  /// This launch's probe per origin, kept after it finishes so only one runs.
  private var probes: [String: (startedAt: Date, task: Task<Void, Never>)] = [:]
  /// Origins whose probe has answered this launch.
  private var finished: Set<String> = []
  /// What this launch's probe answered, when it couldn't measure.
  private var unmeasured: [String: WebApplePayReadiness] = [:]
  /// Audience evaluations held for a first answer.
  private var waiters: [UUID: (origin: String, continuation: CheckedContinuation<Void, Never>)] = [:]

  init(
    load: () -> WebApplePayMeasurement?,
    save: @escaping (WebApplePayMeasurement) -> Void,
    measure: @escaping Measure = { origin in await WebApplePayProbe(origin: origin).run() },
    now: @escaping () -> Date = Date.init
  ) {
    self.stored = load()
    self.save = save
    self.measure = measure
    self.now = now
  }

  /// The origin web checkout and teleported paywalls are served from: the web
  /// app's domain when the config sends it, otherwise the origin of its restore
  /// page, which is on the same domain. Only https origins, since Apple Pay
  /// refuses anything else.
  static func checkoutOrigin(from config: Config?) -> URL? {
    guard let web2appConfig = config?.web2appConfig else {
      return nil
    }
    let url = web2appConfig.domainBaseURL ?? web2appConfig.restoreAccessURL
    guard
      url.scheme?.lowercased() == "https",
      let host = url.host,
      !host.isEmpty
    else {
      return nil
    }
    var components = URLComponents()
    components.scheme = "https"
    components.host = host.lowercased()
    components.port = url.port
    return components.url
  }

  /// The value audience rules and paywalls see.
  func readiness(at origin: URL?, isEnabled: Bool) -> WebApplePayReadiness {
    guard isEnabled else {
      return .unknown(.disabled)
    }
    guard let origin = origin else {
      return .unknown(.noCheckoutDomain)
    }
    let key = origin.absoluteString
    if let stored = stored,
      stored.origin == key,
      let readiness = WebApplePayReadiness(measuredRawValue: stored.readiness) {
      return readiness
    }
    return unmeasured[key] ?? .unknown(.notMeasured)
  }

  /// Starts this launch's one refresh for `origin`, if it hasn't started.
  /// Returns at once; the answer is stored when the probe finishes, however
  /// long after the launch that is.
  @discardableResult
  func refreshIfNeeded(at origin: URL) -> Task<Void, Never> {
    let key = origin.absoluteString
    if let probe = probes[key] {
      return probe.task
    }
    let task = Task {
      let outcome = await measure(origin)
      record(outcome, at: key)
    }
    probes[key] = (now(), task)
    return task
  }

  /// Holds audience evaluation for a device with no stored answer for `origin`
  /// until the first probe answers, or until `budget` seconds after that probe
  /// started. A device with a stored answer returns at once. Without this, an
  /// audience on the first launch's first placement would always see
  /// `unknown:notMeasured`, which is exactly the launch a rule is written for.
  func waitForFirstMeasurement(
    at origin: URL,
    budget: TimeInterval = firstMeasurementBudget
  ) async {
    let key = origin.absoluteString
    guard stored?.origin != key else {
      return
    }
    refreshIfNeeded(at: origin)
    guard !finished.contains(key) else {
      return
    }
    let startedAt = probes[key]?.startedAt ?? now()
    let remaining = budget - now().timeIntervalSince(startedAt)
    guard remaining > 0 else {
      return
    }
    let id = UUID()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      waiters[id] = (key, continuation)
      Task { [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        await self?.resumeWaiter(id)
      }
    }
  }

  /// Resumed by whichever comes first, the answer or the end of the budget.
  private func resumeWaiter(_ id: UUID) {
    waiters.removeValue(forKey: id)?.continuation.resume()
  }

  private func resumeWaiters(at origin: String) {
    for (id, waiter) in waiters where waiter.origin == origin {
      waiters[id] = nil
      waiter.continuation.resume()
    }
  }

  private func record(_ outcome: WebApplePayProbe.Outcome, at origin: String) {
    finished.insert(origin)
    defer {
      resumeWaiters(at: origin)
    }
    let durationMs = Int(outcome.duration * 1000)
    guard !outcome.readiness.isUnknown else {
      unmeasured[origin] = outcome.readiness
      Logger.debug(
        logLevel: .debug,
        scope: .device,
        message: "Couldn't measure web Apple Pay readiness at \(origin): "
          + "\(outcome.readiness.rawValue) after \(durationMs)ms",
        info: ["failureReason": outcome.failureReason ?? ""]
      )
      return
    }
    let measurement = WebApplePayMeasurement(
      origin: origin,
      readiness: outcome.readiness.rawValue,
      measuredAt: now()
    )
    stored = measurement
    unmeasured[origin] = nil
    save(measurement)
    Logger.debug(
      logLevel: .debug,
      scope: .device,
      message: "Web Apple Pay readiness at \(origin): \(outcome.readiness.rawValue) after \(durationMs)ms"
    )
  }
}
