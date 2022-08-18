//
//  File.swift
//  
//
//  Created by Jake Mor on 8/18/22.
//

import Foundation
import UIKit

class SWShimmerView: UIView {

  var newPlaceholderView: UIImageView {
    // swiftlint:disable:next force_unwrapping
    let placeholder = UIImage(named: "paywall_placeholder", in: Bundle.module, compatibleWith: nil)!
    let imageView = UIImageView(image: placeholder)
    imageView.frame = self.bounds
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .white
    imageView.backgroundColor = .clear
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.isHidden = false
    return imageView
  }

  lazy var maskImageView = newPlaceholderView
  lazy var imageView = newPlaceholderView

  lazy var gradientLayer: CAGradientLayer = {
    let gradientLayer = CAGradientLayer()
    gradientLayer.frame = self.bounds
    gradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
    gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    return gradientLayer
  }()

  lazy var animation: CABasicAnimation = {
    let animation = CABasicAnimation(keyPath: "transform.translation.x")
    animation.fromValue = -self.frame.width
    animation.toValue = self.frame.width
    animation.repeatCount = .infinity
    animation.duration = 2.0
    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    animation.isRemovedOnCompletion = false
    return animation
  }()

  var isShimmering: Bool = false {
    didSet {
      if isShimmering == oldValue {
        return
      }

      alpha = 1.0
      transform = .identity

      if isShimmering {
        gradientLayer.add(animation, forKey: animation.keyPath)
      } else {
        for layer in layer.sublayers ?? [CALayer]() {
          layer.removeAllAnimations()
        }
      }
    }
  }

  var isLightBackground = false

  var contentColor: UIColor = .black {
    didSet {
      imageView.tintColor = isLightBackground ? contentColor.withAlphaComponent(0.5) : contentColor.withAlphaComponent(0.5)
      let edgesColor:CGColor = UIColor.white.withAlphaComponent(0.0).cgColor
      let centerColor:CGColor = UIColor.white.withAlphaComponent(isLightBackground ? 0.3 : 0.125).cgColor
      gradientLayer.colors = [edgesColor, centerColor, edgesColor]
      gradientLayer.locations = [0.3, 0.5, 0.7]
    }
  }


  override init(frame: CGRect) {
    super.init(frame: frame)
    translatesAutoresizingMaskIntoConstraints = false
    layer.insertSublayer(gradientLayer, at: 0)
    mask = maskImageView
    insertSubview(imageView, at: 0)
    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
      imageView.topAnchor.constraint(equalTo: self.topAnchor),
      imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
    ])
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    maskImageView.frame = imageView.bounds
    checkIfLandscape()
    animation.fromValue = -imageView.bounds.width
    animation.toValue = imageView.bounds.width
  }

  var isLandscape = false

  func checkIfLandscape() {

    if isLandscape == UIWindow.isLandscape {
      return
    } else {
      isLandscape = UIWindow.isLandscape
    }

    if UIWindow.isLandscape {
      if let placeholder = UIImage(
        named: "paywall_placeholder_landscape",
        in: Bundle.module,
        compatibleWith: nil
      ) {
        maskImageView.image = placeholder
        imageView.image = placeholder
        imageView.tintColor = contentColor
        imageView.alpha = 0.4
      }
    } else {
      if let placeholder = UIImage(
        named: "paywall_placeholder",
        in: Bundle.module,
        compatibleWith: nil
      ) {
        maskImageView.image = placeholder
        imageView.image = placeholder
        imageView.tintColor = contentColor
        imageView.alpha = 1.0
      }
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

}
