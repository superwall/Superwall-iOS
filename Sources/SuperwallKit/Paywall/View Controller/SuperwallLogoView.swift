//
//  SuperwallLogoView.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 24/11/2024.
//

import UIKit

/// A view that displays the Superwall logo behind the notch on full-screen paywalls.
/// Only visible on devices with a top notch (Face ID capable) in portrait orientation.
final class SuperwallLogoView: UIView {
  private let logoImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.image = UIImage(
      named: "SuperwallKit_superwall_logo",
      in: Bundle.module,
      compatibleWith: nil
    )
    return imageView
  }()

  private var topConstraint: NSLayoutConstraint?

  /// Tracks whether we were in portrait to detect rotation changes
  private var wasPortrait: Bool = !UIWindow.isLandscape

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
    setupOrientationObserver()
    updateVisibility()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let isPortrait = !UIWindow.isLandscape

    // If orientation changed, hide immediately to avoid showing during rotation
    if isPortrait != wasPortrait {
      alpha = 0
      wasPortrait = isPortrait
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func setupView() {
    translatesAutoresizingMaskIntoConstraints = false
    isUserInteractionEnabled = false

    addSubview(logoImageView)

    let topConstraint = logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: topPadding)
    self.topConstraint = topConstraint

    NSLayoutConstraint.activate([
      logoImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
      topConstraint,
      logoImageView.widthAnchor.constraint(equalToConstant: 86),
      logoImageView.heightAnchor.constraint(equalToConstant: 40),
      logoImageView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }

  private func setupOrientationObserver() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(orientationDidChange),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
  }

  @objc private func orientationDidChange() {
    updateVisibility()
  }

  private func updateVisibility() {
    let shouldShow = Self.deviceHasTopNotch && !UIWindow.isLandscape
    alpha = shouldShow ? 1 : 0
    topConstraint?.constant = topPadding
  }

  /// Shows the logo if orientation allows (portrait only).
  func show() {
    updateVisibility()
  }

  /// Top padding calculation to center the logo within the notch area
  private var topPadding: CGFloat {
    guard let window = UIApplication.sharedApplication?.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first?
      .windows
      .first(where: { $0.isKeyWindow }) else {
      return 4
    }
    // Center the logo vertically within the safe area inset (the notch area)
    // Logo height is 40, so offset by (safeAreaTop - 40) / 2
    let safeAreaTop = window.safeAreaInsets.top
    return max(4, (safeAreaTop - 40) / 2)
  }

  /// Returns true if the device has a top notch (Face ID capable device).
  static var deviceHasTopNotch: Bool = {
    #if os(visionOS)
    return false
    #else
    guard let window = UIApplication.sharedApplication?.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first?
      .windows
      .first(where: { $0.isKeyWindow }) else {
      return false
    }
    // Devices with Face ID have a top safe area inset > 20
    return window.safeAreaInsets.top > 20
    #endif
  }()
}
