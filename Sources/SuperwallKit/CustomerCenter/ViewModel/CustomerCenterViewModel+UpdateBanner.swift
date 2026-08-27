//
//  CustomerCenterViewModel+UpdateBanner.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Foundation

// MARK: - Update banner

@available(iOS 15.0, *)
extension CustomerCenterViewModel {
  /// The version the banner compares against: whatever the host configured, otherwise whatever the
  /// App Store lookup returned. A configured value always wins and suppresses the lookup entirely.
  private var latestKnownAppVersion: String? {
    configuration.support.latestAppVersion ?? fetchedAppStoreVersion
  }

  func recomputeUpdateBanner() {
    showsUpdateBanner = !updateWarningDismissed
      && configuration.support.shouldWarnToUpdate
      && AppVersionComparator.isInstalledVersion(
        dependencies.environment.appVersion,
        olderThan: latestKnownAppVersion
      )
  }

  /// Asks the App Store what version is published, then re-evaluates the banner.
  ///
  /// Skipped on TestFlight, sandbox and simulator builds: their version is normally *ahead* of the
  /// published one, so the comparison would either be meaningless or send a tester "back" to an
  /// older build. Also skipped when the host set `latestAppVersion`, which is authoritative.
  func refreshAppStoreVersion() async {
    guard
      configuration.support.shouldWarnToUpdate,
      configuration.support.checksAppStoreForUpdates,
      configuration.support.latestAppVersion == nil,
      !dependencies.environment.isSandbox,
      !hasCheckedAppStoreVersion
    else {
      return
    }
    hasCheckedAppStoreVersion = true
    guard let version = await dependencies.appStoreVersion.latestAppStoreVersion() else { return }
    fetchedAppStoreVersion = version
    recomputeUpdateBanner()
  }

  func continueAfterUpdateWarning() {
    updateWarningDismissed = true
    showsUpdateBanner = false
  }
}
