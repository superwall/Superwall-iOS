//
//  SWBounceButton.swift
//  
//
//  Created by Jake Mor on 8/27/21.
//

import Foundation
import UIKit
import AVFoundation

protocol BounceButtonToggleDelegate: AnyObject {
  func buttonDidToggle(
    _ button: SWBounceButton,
    isOn: Bool
  )
}

final class SWBounceButton: UIButton {
  // MARK: - Properties
  var greedyTouches = true
  var toggleValue: Any?
  var toggleKey = "key"
  var isOn = false
  var canToggle = false

  var oldTitle: String = ""

  var showLoading = false {
    didSet {
      if showLoading {
        if oldTitle.isEmpty {
          oldTitle = self.titleLabel?.text ?? ""
        }
        self.setTitle("", for: .normal)
        self.activityIndicator.startAnimating()
        self.isEnabled = false
      } else {
        self.setTitle(oldTitle, for: .normal)
        self.oldTitle = ""
        self.activityIndicator.stopAnimating()
        self.isEnabled = true
      }
    }
  }

  private let activityIndicator: UIActivityIndicatorView = {
    let view = UIActivityIndicatorView()
    view.hidesWhenStopped = true
    view.stopAnimating()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.color = primaryColor
    return view
  }()

  var customTint: UIColor? {
    didSet {
      if let customTint = customTint {
        backgroundColor = customTint.withAlphaComponent(0.15)
        setTitleColor(customTint, for: .normal)
      }
    }
  }

  var onBackgroundColor: UIColor = primaryButtonBackgroundColor
  var offBackgroundColor: UIColor = secondaryButtonBackgroundColor

  weak var bounceButtonToggleDelegate: BounceButtonToggleDelegate?

  var shouldOnlyAnimateText = false

  var shouldAnimateLightly = false

  var didAddTargetForCustomAction = false

  var action: ((SWBounceButton) -> Void)? {
    didSet {
      if !didAddTargetForCustomAction {
        addTarget(self, action: #selector(tapped(sender:)), for: .primaryActionTriggered)
        didAddTargetForCustomAction = true
      }
    }
  }

  override var isHighlighted: Bool {
    didSet {
      if shouldOnlyAnimateText {
        animateTitleScale(shrink: isHighlighted)
      } else {
        if shouldAnimateLightly {
          animateScaleLightly(shrink: isHighlighted)
        } else {
          animateScale(shrink: isHighlighted)
        }
      }
      super.isHighlighted = isHighlighted
    }
  }

  private var _borderColor: UIColor?
  var borderColor: UIColor? {
    didSet {
      _borderColor = borderColor
      self.layer.borderColor = (borderColor ?? UIColor.clear).cgColor
    }
  }

  // MARK: - Initializers
  convenience init() {
    self.init(frame: CGRect())
    adjustsImageWhenHighlighted = false
  }

  override init(frame: CGRect) {
    super.init(frame: frame)

    setTitleColor(.black, for: .normal)
    addTarget(self, action: #selector(tappedBounceButton(sender:)), for: .primaryActionTriggered)

    addSubview(activityIndicator)

    NSLayoutConstraint.activate([
      activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc func tapped(sender: SWBounceButton) {
    action?(self)
  }

  @objc func tappedBounceButton(sender: SWBounceButton) {
    if isEnabled {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      // AudioServicesPlayAlertSound(1104)
    }

    shouldToggle()
  }

  func shouldToggle() {
    if canToggle {
      isOn.toggle()
      bounceButtonToggleDelegate?.buttonDidToggle(self, isOn: isOn)
      backgroundColor = isOn ? onBackgroundColor : offBackgroundColor
    }
  }

  // MARK: - Animations

  func animateScale(shrink: Bool) {
    let duration = shrink ? 0.2 : 0.4
    let damping: CGFloat = shrink ? 1 : 0.3
    let scale: CGFloat = shrink ? 0.9 : 1

    UIView.animate(
      withDuration: duration,
      delay: 0,
      usingSpringWithDamping: damping,
      initialSpringVelocity: 0,
      options: [.allowUserInteraction, .curveEaseInOut]
    ) {
      self.transform = CGAffineTransform(scaleX: scale, y: scale)
      self.titleLabel?.alpha = shrink ? 0.5 : 1.0
      self.imageView?.alpha = shrink ? 0.5 : 1.0
    }
  }

  private func animateScaleLightly(shrink: Bool) {
    let duration = shrink ? 0.2 : 0.4
    let damping: CGFloat = shrink ? 1 : 0.35
    let scale: CGFloat = shrink ? 0.95 : 1

    UIView.animate(
      withDuration: duration,
      delay: shrink ? 0 : 0.05,
      usingSpringWithDamping: damping,
      initialSpringVelocity: 0,
      options: [.allowUserInteraction, .curveEaseInOut]
    ) {
      self.transform = CGAffineTransform(scaleX: scale, y: scale)
      self.titleLabel?.alpha = shrink ? 0.5 : 1.0
      self.imageView?.alpha = shrink ? 0.5 : 1.0
    }
  }

  private func animateTitleScale(shrink: Bool) {
    let duration = shrink ? 0.2 : 0.4
    let damping: CGFloat = 1
    let alpha: CGFloat = shrink ? 0.5 : 1

    UIView.animate(
      withDuration: duration,
      delay: 0,
      usingSpringWithDamping: damping,
      initialSpringVelocity: 0,
      options: [.allowUserInteraction, .curveEaseInOut]
    ) {
      self.titleLabel?.alpha = alpha
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    self.borderColor = _borderColor
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    if canToggle {
      backgroundColor = isOn ? onBackgroundColor : offBackgroundColor
    }
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // if the button is hidden/disabled/transparent it can’t be hit
    if self.isHidden || !self.isUserInteractionEnabled || self.alpha < 0.01 { return nil }

    let inset: CGFloat = greedyTouches ? -15 : -10

    let largerFrame = self.bounds.insetBy(dx: inset, dy: inset)

    // perform hit test on larger frame
    return (largerFrame.contains(point)) ? self : nil
  }
}
