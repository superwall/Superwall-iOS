//
//  File.swift
//  
//
//  Created by Jake Mor on 8/17/22.
//
// swiftlint:disable identifier_name

import Foundation
import UIKit

final class SWPaywallLoadingView: UIView {
  private var isEnabled: Bool {
    if let background = Superwall.options.paywalls.transactionBackgroundView,
      background == .spinner {
      return true
    } else {
      return false
    }
  }

  var paywallBackgroundColor: UIColor = .white

  private var outerContainer: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isUserInteractionEnabled = false
    view.clipsToBounds = false
    return view
  }()

  var darkBlurEffectView: UIVisualEffectView = {
    let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return blurEffectView
  }()

  private lazy var activityContainer: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isUserInteractionEnabled = false
    return view
  }()

  private lazy var innerContainer: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isUserInteractionEnabled = false
    view.clipsToBounds = true
    darkBlurEffectView.frame = view.bounds
    view.addSubview(darkBlurEffectView)
    view.layer.cornerCurve = .continuous
    view.layer.cornerRadius = 15
    return view
  }()

  private var innerContainerShadow = SWShadowView()

  private var activityIndicator: UIActivityIndicatorView = {
    let spinner = UIActivityIndicatorView()
    spinner.color = .white
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.style = .large
    spinner.hidesWhenStopped = true
    return spinner
  }()

  init() {
    super.init(frame: CGRect())
    translatesAutoresizingMaskIntoConstraints = false
    isHidden = true
    isUserInteractionEnabled = true
    addSubview(outerContainer)
    outerContainer.addSubview(activityContainer)
    activityContainer.addSubview(innerContainerShadow)
    activityContainer.addSubview(innerContainer)
    innerContainer.addSubview(activityIndicator)
    NSLayoutConstraint.activate([
      outerContainer.widthAnchor.constraint(equalTo: widthAnchor),
      outerContainer.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5),
      outerContainer.topAnchor.constraint(equalTo: topAnchor),
      outerContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
      activityContainer.centerXAnchor.constraint(equalTo: outerContainer.centerXAnchor),
      activityContainer.centerYAnchor.constraint(equalTo: outerContainer.bottomAnchor),
      activityContainer.widthAnchor.constraint(equalToConstant: 100),
      activityContainer.heightAnchor.constraint(equalToConstant: 100),
      innerContainer.centerXAnchor.constraint(equalTo: activityContainer.centerXAnchor),
      innerContainer.centerYAnchor.constraint(equalTo: activityContainer.centerYAnchor),
      innerContainer.widthAnchor.constraint(equalToConstant: 75),
      innerContainer.heightAnchor.constraint(equalToConstant: 75),
      innerContainerShadow.centerXAnchor.constraint(equalTo: activityContainer.centerXAnchor),
      innerContainerShadow.centerYAnchor.constraint(equalTo: activityContainer.centerYAnchor),
      innerContainerShadow.widthAnchor.constraint(equalToConstant: 75),
      innerContainerShadow.heightAnchor.constraint(equalToConstant: 75),
      activityIndicator.centerXAnchor.constraint(equalTo: innerContainer.centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: innerContainer.centerYAnchor)
    ])
  }

  func toggle(show: Bool, animated: Bool) {
    guard isEnabled else {
      return
    }
    if show && activityIndicator.isAnimating {
      return
    } else if !show && !activityIndicator.isAnimating {
      return
    }

    superview?.bringSubviewToFront(self)
    if show {
      activityIndicator.startAnimating()
      activityContainer.alpha = 0.0
      activityContainer.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
      activityIndicator.transform = CGAffineTransform(rotationAngle: CGFloat.pi )
      outerContainer.transform = .identity
      isHidden = false
      backgroundColor = UIColor.black.withAlphaComponent(0.0)
      UIView.springAnimate { [weak self] in
        self?.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        self?.activityContainer.alpha = 1.0
        self?.activityContainer.transform = .identity
        self?.activityIndicator.transform = .identity
      }
    } else {
      activityContainer.alpha = 1.0
      activityContainer.transform = .identity
      UIView.springAnimate { [weak self] in
        self?.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        self?.activityContainer.alpha = 0.0
        self?.activityContainer.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
        self?.activityIndicator.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
      } completion: { [weak self] _ in
        self?.activityIndicator.stopAnimating()
        self?.isHidden = true
      }
    }
  }

  func move(up: Bool) {
    UIView.springAnimate { [weak self] in
      if up {
        if let height = self?.outerContainer.frame.size.height {
          self?.outerContainer.transform = CGAffineTransform.identity.translatedBy(
            x: 0,
            y: height * 0.5 * -1
          )
        }
      } else {
        self?.outerContainer.transform = .identity
      }
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

final class SWShadowView: UIView {
  let corner: CGFloat = 15

  init() {
    super.init(frame: CGRect())
    isUserInteractionEnabled = false
    translatesAutoresizingMaskIntoConstraints = false
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.masksToBounds = false
    layer.shadowRadius = 20
    layer.shadowOpacity = 0
    layer.shadowOffset = .zero
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 15).cgPath
  }
}
