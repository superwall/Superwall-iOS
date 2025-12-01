//
//  DynamicIslandInfo.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 26/11/2025.
//

#if !os(visionOS)
import UIKit

/// Information about the Dynamic Island or notch for positioning UI elements like the Superwall logo.
struct DynamicIslandInfo {
  /// Whether the current device has a Dynamic Island.
  let hasDynamicIsland: Bool

  /// Whether the current device has a notch (but not a Dynamic Island).
  let hasNotch: Bool

  /// Whether the current device has either a Dynamic Island or a notch.
  var hasDynamicIslandOrNotch: Bool {
    hasDynamicIsland || hasNotch
  }

  /// The width of the Dynamic Island in points. Zero for notch devices.
  let width: CGFloat

  /// The height of the Dynamic Island in points. Zero for notch devices.
  let height: CGFloat

  /// The corner radius of the Dynamic Island in points (half the height for capsule shape).
  static let cornerRadius: CGFloat = 18.32

  /// The top padding from the screen edge to the Dynamic Island or notch.
  let topPadding: CGFloat

  /// The frame of the Dynamic Island relative to the screen.
  var frame: CGRect {
    guard hasDynamicIsland else { return .zero }
    let screenWidth = UIScreen.main.bounds.width
    let x = (screenWidth - width) / 2
    return CGRect(x: x, y: topPadding, width: width, height: height)
  }

  /// The area to the left of the Dynamic Island (left "ear").
  var leftEarFrame: CGRect {
    guard hasDynamicIsland else { return .zero }
    let screenWidth = UIScreen.main.bounds.width
    let earWidth = (screenWidth - width) / 2
    return CGRect(x: 0, y: topPadding, width: earWidth, height: height)
  }

  /// The area to the right of the Dynamic Island (right "ear").
  var rightEarFrame: CGRect {
    guard hasDynamicIsland else { return .zero }
    let screenWidth = UIScreen.main.bounds.width
    let earWidth = (screenWidth - width) / 2
    let x = screenWidth - earWidth
    return CGRect(x: x, y: topPadding, width: earWidth, height: height)
  }

  /// The width of one ear (left or right area beside the Dynamic Island).
  var earWidth: CGFloat {
    guard hasDynamicIsland else { return 0 }
    let screenWidth = UIScreen.main.bounds.width
    return (screenWidth - width) / 2
  }

  /// The maximum logo width that can fit in an ear with padding.
  /// Returns 0 if there's no Dynamic Island.
  var maxLogoWidthInEar: CGFloat {
    guard hasDynamicIsland else { return 0 }
    // Leave 8pt padding on each side
    return earWidth - 16
  }

  /// Gets the Dynamic Island info for the current device.
  static var current: DynamicIslandInfo {
    let modelName = UIDevice.modelName
    return DynamicIslandInfo(for: modelName)
  }

  /// Creates Dynamic Island info for a specific device model identifier.
  /// - Parameter modelIdentifier: The device model identifier (e.g., "iPhone15,2").
  ///
  /// Dynamic Island widths from Apple HIG:
  /// https://developer.apple.com/design/human-interface-guidelines/live-activities#Specifications
  init(for modelIdentifier: String) {
    if DeviceSets.width230Devices.contains(modelIdentifier) {
      self = Self.makeDynamicIsland230(for: modelIdentifier)
    } else if DeviceSets.width250Devices.contains(modelIdentifier) {
      self = Self.makeDynamicIsland250(for: modelIdentifier)
    } else if DeviceSets.notchDevices.contains(modelIdentifier) {
      self = Self.makeNotch()
    } else {
      self = Self.makeUnknown()
    }
  }
}

// MARK: - Device Sets

private enum DeviceSets {
  /// Devices with 230pt Dynamic Island width
  static let width230Devices: Set<String> = [
    "iPhone15,2", // iPhone 14 Pro
    "iPhone15,4", // iPhone 15
    "iPhone16,1", // iPhone 15 Pro
    "iPhone17,1", // iPhone 16 Pro
    "iPhone17,3", // iPhone 16
    "iPhone18,1", // iPhone 17 Pro
    "iPhone18,3"  // iPhone 17
  ]

  /// Devices with 250pt Dynamic Island width (larger phones: Plus/Pro Max/Air)
  static let width250Devices: Set<String> = [
    "iPhone15,3", // iPhone 14 Pro Max
    "iPhone15,5", // iPhone 15 Plus
    "iPhone16,2", // iPhone 15 Pro Max
    "iPhone17,2", // iPhone 16 Pro Max
    "iPhone17,4", // iPhone 16 Plus
    "iPhone18,2", // iPhone 17 Pro Max
    "iPhone18,4"  // iPhone Air
  ]

  /// Devices with notch (but not Dynamic Island)
  static let notchDevices: Set<String> = [
    "iPhone10,3", "iPhone10,6", // iPhone X
    "iPhone11,2",               // iPhone XS
    "iPhone11,4", "iPhone11,6", // iPhone XS Max
    "iPhone11,8",               // iPhone XR
    "iPhone12,1",               // iPhone 11
    "iPhone12,3",               // iPhone 11 Pro
    "iPhone12,5",               // iPhone 11 Pro Max
    "iPhone13,1",               // iPhone 12 mini
    "iPhone13,2",               // iPhone 12
    "iPhone13,3",               // iPhone 12 Pro
    "iPhone13,4",               // iPhone 12 Pro Max
    "iPhone14,4",               // iPhone 13 mini
    "iPhone14,5",               // iPhone 13
    "iPhone14,2",               // iPhone 13 Pro
    "iPhone14,3",               // iPhone 13 Pro Max
    "iPhone14,7",               // iPhone 14
    "iPhone14,8",               // iPhone 14 Plus
    "iPhone17,5"                // iPhone 16e
  ]

  /// 230pt devices with 11px top padding
  static let width230TopPadding11: Set<String> = [
    "iPhone15,2", // iPhone 14 Pro
    "iPhone15,4", // iPhone 15
    "iPhone16,1", // iPhone 15 Pro
    "iPhone17,3"  // iPhone 16
  ]

  /// 250pt devices with 11px top padding
  static let width250TopPadding11: Set<String> = [
    "iPhone15,3", // iPhone 14 Pro Max
    "iPhone15,5", // iPhone 15 Plus
    "iPhone16,2", // iPhone 15 Pro Max
    "iPhone17,4"  // iPhone 16 Plus
  ]
}

// MARK: - Factory Methods

private extension DynamicIslandInfo {
  /// 230pt expanded width minus compact leading/trailing (52.33pt each)
  static let width230: CGFloat = 230 - (52.33 * 2) // 125.34pt

  /// 250pt expanded width minus compact leading/trailing (62.33pt each)
  static let width250: CGFloat = 250 - (62.33 * 2) // 125.34pt

  /// Standard Dynamic Island height
  static let dynamicIslandHeight: CGFloat = 36.67

  static func makeDynamicIsland230(for modelIdentifier: String) -> DynamicIslandInfo {
    let topPadding: CGFloat = DeviceSets.width230TopPadding11.contains(modelIdentifier) ? 11 : 14
    return DynamicIslandInfo(
      hasDynamicIsland: true,
      hasNotch: false,
      width: width230,
      height: dynamicIslandHeight,
      topPadding: topPadding
    )
  }

  static func makeDynamicIsland250(for modelIdentifier: String) -> DynamicIslandInfo {
    let topPadding: CGFloat
    if modelIdentifier == "iPhone18,4" { // iPhone Air
      topPadding = 20
    } else if DeviceSets.width250TopPadding11.contains(modelIdentifier) {
      topPadding = 11
    } else {
      topPadding = 14
    }
    return DynamicIslandInfo(
      hasDynamicIsland: true,
      hasNotch: false,
      width: width250,
      height: dynamicIslandHeight,
      topPadding: topPadding
    )
  }

  static func makeNotch() -> DynamicIslandInfo {
    DynamicIslandInfo(
      hasDynamicIsland: false,
      hasNotch: true,
      width: 0,
      height: 0,
      topPadding: 0
    )
  }

  static func makeUnknown() -> DynamicIslandInfo {
    DynamicIslandInfo(
      hasDynamicIsland: false,
      hasNotch: false,
      width: 0,
      height: 0,
      topPadding: 0
    )
  }

  /// Memberwise initializer for factory methods
  private init(
    hasDynamicIsland: Bool,
    hasNotch: Bool,
    width: CGFloat,
    height: CGFloat,
    topPadding: CGFloat
  ) {
    self.hasDynamicIsland = hasDynamicIsland
    self.hasNotch = hasNotch
    self.width = width
    self.height = height
    self.topPadding = topPadding
  }
}
#endif
