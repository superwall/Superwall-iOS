//
//  TestModeManager.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import Foundation

/// Override for free trial availability in test mode.
enum FreeTrialOverride: String, CaseIterable, Sendable {
  /// Use the product's actual free trial availability.
  case useDefault
  /// Force free trial to be available.
  case forceAvailable
  /// Force free trial to be unavailable.
  case forceUnavailable

  var displayName: String {
    switch self {
    case .useDefault:
      return "Use Default"
    case .forceAvailable:
      return "Force Available"
    case .forceUnavailable:
      return "Force Unavailable"
    }
  }
}

/// The reason why the user is in test mode.
enum TestModeReason: Sendable {
  /// The user's alias ID matched a test store user from the config.
  case configMatch

  /// Test mode is always enabled via SuperwallOptions.
  case testModeOption

  /// The app's bundle ID doesn't match the config's `bundleIds.ios`, in a
  /// build that isn't from the App Store.
  case bundleIdMismatch(expected: String, actual: String)

  /// Whether the config itself asked for test mode, as opposed to an option
  /// the app set. Only a config can change between launches, so only these
  /// reasons can come from a config saved by an earlier launch.
  var comesFromConfig: Bool {
    switch self {
    case .configMatch,
      .bundleIdMismatch:
      return true
    case .testModeOption:
      return false
    }
  }

  var description: String {
    switch self {
    case .configMatch:
      return "User is in test mode (enabled from dashboard)"
    case .testModeOption:
      return "Test mode is always enabled via SuperwallOptions"
    case let .bundleIdMismatch(expected, actual):
      return "Bundle ID mismatch: expected \(expected), got \(actual)"
    }
  }
}

/// Manages test mode state for the current user.
///
/// Test mode allows Superwall to simulate purchases without involving
/// StoreKit or external purchase controllers. When active, purchases are
/// faked and entitlements are set directly.
///
/// The state lives in a ``TestModeStore`` and changes only through
/// ``TestModeAction``s, so it can be read from any thread. The manager is the
/// actions' context. It sends test mode's status and customer info to the
/// rest of the SDK one send at a time, in order, on a
/// ``SerialTaskCoordinator``.
final class TestModeManager: TestModeContext {
  let store = TestModeStore(initial: TestModeState())

  /// What test mode knows right now.
  var state: TestModeState {
    store.state
  }

  /// Whether the current user is in test mode.
  var isTestMode: Bool {
    store.read { $0.isActive }
  }

  /// The reason test mode is active, if applicable.
  var testModeReason: TestModeReason? {
    store.read { $0.reason }
  }

  /// Products fetched from the `/v1/products` endpoint for test mode use.
  var products: [SuperwallProduct] {
    store.read { $0.session?.products ?? [] }
  }

  /// The entitlements the tester has picked or bought.
  var testEntitlementIds: Set<String> {
    store.read { $0.session?.entitlementIds ?? [] }
  }

  /// Override for free trial availability. `.useDefault` while test mode is
  /// off.
  var freeTrialOverride: FreeTrialOverride {
    store.read { $0.session?.freeTrialOverride ?? .useDefault }
  }

  /// The subscription status test mode keeps, which replaces other writes to
  /// `subscriptionStatus`. Always `nil` while test mode is off.
  var overriddenSubscriptionStatus: SubscriptionStatus? {
    store.read { $0.session?.overriddenSubscriptionStatus }
  }

  /// The customer info test mode keeps, which replaces other writes to
  /// `customerInfo`. Always `nil` while test mode is off.
  var overriddenCustomerInfo: CustomerInfo? {
    store.read { $0.session?.overriddenCustomerInfo }
  }

  /// Whether the process is running inside a test environment.
  /// Returns `false` when `SUPERWALL_UNIT_TESTS` launch argument is present
  /// (used by internal unit tests to avoid skipping test mode).
  static let isTestEnvironment: Bool = {
    if ProcessInfo.processInfo.arguments.contains("SUPERWALL_UNIT_TESTS") {
      return false
    }
    return NSClassFromString("XCTestCase") != nil
  }()

  /// Whether the app is running outside App Store production: simulator,
  /// TestFlight or a development build. Replaced in tests.
  var isSandboxEnvironment: () -> Bool = { DeviceHelper.isSandboxEnvironment }

  unowned let identityManager: IdentityManager
  private unowned let deviceHelper: DeviceHelper
  private unowned let storage: Storage
  /// Where the test mode modal saves the tester's choices.
  let defaults: UserDefaults
  private let statusSink: TestModeStatusSink
  /// Sends the status and customer info one at a time, in order.
  private let publishing = SerialTaskCoordinator()

  init(
    identityManager: IdentityManager,
    deviceHelper: DeviceHelper,
    storage: Storage,
    defaults: UserDefaults = .standard,
    statusSink: TestModeStatusSink = SuperwallTestModeStatusSink()
  ) {
    self.identityManager = identityManager
    self.deviceHelper = deviceHelper
    self.storage = storage
    self.defaults = defaults
    self.statusSink = statusSink
  }

  /// Runs `action` and returns the state before and after it.
  @discardableResult
  func dispatch(_ action: TestModeAction) -> TestModeChange {
    store.dispatch(action, in: self)
  }

  /// Waits for the status and customer info sends queued so far.
  func finishPublishing() async {
    await publishing.flush()
  }

  /// Evaluates whether the current user should be in test mode based on the config
  /// and the `testModeBehavior` option. Called on every config refresh.
  ///
  /// - Returns: The state before and after, so callers can tell whether test
  ///   mode just turned on or off.
  @discardableResult
  func evaluateTestMode(config: Config, options: SuperwallOptions) -> TestModeChange {
    // Worked out before dispatching, since it reads the identity.
    let reason = reasonForTestMode(
      config: config,
      options: options,
      warnAboutIgnoredMismatch: true
    )
    return dispatch(.evaluated(reason))
  }

  /// Why `config` and `options` would put the current user in test mode, or
  /// `nil` if they wouldn't. Changes nothing, so a config can be checked before
  /// it is used.
  func reasonForTestMode(config: Config, options: SuperwallOptions) -> TestModeReason? {
    return reasonForTestMode(config: config, options: options, warnAboutIgnoredMismatch: false)
  }

  private func reasonForTestMode(
    config: Config,
    options: SuperwallOptions,
    warnAboutIgnoredMismatch: Bool
  ) -> TestModeReason? {
    #if !canImport(WebKit)
    // Test mode picks entitlements and simulates purchases in its own screens,
    // which watchOS and tvOS don't have.
    return nil
    #else
    if DevMode.isActive(options) {
      return .testModeOption
    }
    switch options.testModeBehavior {
    case .never:
      return nil
    case .always:
      return .testModeOption
    case .whenEnabledForUser:
      // Only check user ID match, skip bundle ID check
      return configMatchReason(config: config)
    case .automatic:
      // Skip entirely if in UI tests
      if Self.isTestEnvironment {
        return nil
      }
      // Check user match, then bundle ID mismatch
      return configMatchReason(config: config)
        ?? bundleIdMismatchReason(config: config, warnIfIgnored: warnAboutIgnoredMismatch)
    }
    #endif
  }

  /// Whether `config` itself would put the current user in test mode. Such a
  /// config must never be the one a launch starts from: see
  /// `ConfigManager.cachedConfigForLaunch()`.
  func isPutInTestMode(by config: Config, options: SuperwallOptions) -> Bool {
    return reasonForTestMode(config: config, options: options)?.comesFromConfig == true
  }

  /// The reason if the current user's ID or alias matches any test store user in the config.
  private func configMatchReason(config: Config) -> TestModeReason? {
    let testModeUserIds = config.testModeUserIds ?? []
    let aliasId = identityManager.aliasId
    let appUserId = identityManager.appUserId

    for testUser in testModeUserIds {
      switch testUser.type {
      case .userId:
        if let appUserId, appUserId == testUser.value {
          return .configMatch
        }
      case .aliasId:
        if aliasId == testUser.value {
          return .configMatch
        }
      }
    }
    return nil
  }

  /// The reason if the app's bundle ID differs from the config's expected bundle ID.
  /// App extensions are allowed because their bundle ID uses the main app's
  /// bundle ID as a prefix (e.g., `com.example.app.widget-extension`).
  ///
  /// - Parameter warnIfIgnored: Whether to log when an App Store build ignores
  ///   the mismatch. Only set when the config is being applied, so the warning
  ///   shows once per config rather than on every check.
  private func bundleIdMismatchReason(config: Config, warnIfIgnored: Bool) -> TestModeReason? {
    guard
      let expectedBundleId = config.bundleIdConfig,
      let actualBundleId = Bundle.main.bundleIdentifier,
      expectedBundleId != actualBundleId,
      !actualBundleId.hasPrefix(expectedBundleId + ".")
    else {
      return nil
    }
    // A mismatch is how a developer's own build gets into test mode without
    // any setup. An App Store install is a customer's, and the mismatch there
    // means the bundle ID on the dashboard was edited, which must not replace
    // their real purchases with simulated ones. Test users marked on the
    // dashboard still get test mode in an App Store build.
    guard isSandboxEnvironment() else {
      if !warnIfIgnored {
        return nil
      }
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "The app's bundle ID is \(actualBundleId) but the Superwall dashboard expects "
          + "\(expectedBundleId). Ignoring the mismatch because this is an App Store build, "
          + "so test mode stays off. Correct the bundle ID in the dashboard's app settings."
      )
      return nil
    }
    return .bundleIdMismatch(expected: expectedBundleId, actual: actualBundleId)
  }

  // MARK: - TestModeContext

  func clearSavedSettings() {
    #if canImport(WebKit)
    TestModeSettingsStore.clear(in: defaults)
    #endif
    storage.save(false, forType: IsTestModeActiveSubscription.self)
  }

  func saveHasActiveSubscription(_ hasActiveSubscription: Bool) {
    storage.save(hasActiveSubscription, forType: IsTestModeActiveSubscription.self)
  }

  func publishOverrides() {
    publishing.enqueue { [weak self] in
      await self?.sendOverrides()
    }
  }

  func publishTestModeEnded() {
    publishing.enqueue { [weak self] in
      await self?.sendTestModeEnded()
    }
  }

  @MainActor
  private func sendOverrides() {
    let session = store.read { $0.session }
    guard
      let status = session?.overriddenSubscriptionStatus,
      let customerInfo = session?.overriddenCustomerInfo
    else {
      return
    }
    statusSink.send(customerInfo: customerInfo, status: status)
  }

  @MainActor
  private func sendTestModeEnded() {
    if isTestMode {
      return
    }
    statusSink.sendTestModeEnded()
  }
}

extension FreeTrialOverride {
  /// Whether a free trial should be shown for `product`, with this override.
  func showsFreeTrial(for product: StoreProduct) -> Bool {
    switch self {
    case .useDefault:
      return product.hasFreeTrial
    case .forceAvailable:
      return true
    case .forceUnavailable:
      return false
    }
  }
}
