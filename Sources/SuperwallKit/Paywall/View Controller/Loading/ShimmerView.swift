//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/10/2022.
//

import UIKit

final class ShimmerView: UIImageView {
  private let isLightBackground: Bool
  private lazy var gradientLayer: CAGradientLayer = {
    let gradientLayer = CAGradientLayer()
    gradientLayer.frame = self.bounds
    gradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
    gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)

    let edgesColor = UIColor.white.withAlphaComponent(0.0).cgColor
    let centerColor = UIColor.white.withAlphaComponent(isLightBackground ? 0.5 : 0.2).cgColor
    gradientLayer.colors = [edgesColor, centerColor, edgesColor]
    gradientLayer.locations = [0, 0.5, 1.0]
    gradientLayer.add(animation, forKey: animation.keyPath)
    return gradientLayer
  }()

  private var placeholderImage: UIImage {
    if UIWindow.isLandscape {
      guard let placeholder = UIImage(
        named: "paywall_placeholder_landscape",
        in: Bundle.module,
        compatibleWith: nil
      ) else {
        return UIImage()
      }
      alpha = 0.4
      return placeholder
    } else {
      guard let placeholder = UIImage(
        named: "paywall_placeholder",
        in: Bundle.module,
        compatibleWith: nil
      ) else {
        return UIImage()
      }
      alpha = 1
      return placeholder
    }
  }

  private lazy var animation: CABasicAnimation = {
    let animation = CABasicAnimation(keyPath: "locations")
    animation.fromValue = [-1.0, -0.5, 0.0]
    animation.toValue = [1.0, 1.5, 2.0]
    animation.repeatCount = .infinity
    animation.duration = 2.0
    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    animation.isRemovedOnCompletion = false
    return animation
  }()

  private let shimmerImageView = UIImageView()

  init(
    backgroundColor: UIColor,
    tintColor: UIColor,
    isLightBackground: Bool
  ) {
    self.isLightBackground = isLightBackground
    super.init(frame: .zero)

    // add the shimmer
    addSubview(shimmerImageView)
    NSLayoutConstraint.activate([
      shimmerImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
      shimmerImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
      shimmerImageView.topAnchor.constraint(equalTo: topAnchor),
      shimmerImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    // style
    self.tintColor = tintColor.withAlphaComponent(0.25)
    shimmerImageView.tintColor = tintColor.withAlphaComponent(1.0)

    self.backgroundColor = backgroundColor
    shimmerImageView.backgroundColor = backgroundColor

    translatesAutoresizingMaskIntoConstraints = false
    shimmerImageView.translatesAutoresizingMaskIntoConstraints = false

    image = placeholderImage
    shimmerImageView.image = placeholderImage

    contentMode = .scaleAspectFit
    shimmerImageView.contentMode = .scaleAspectFit

    clipsToBounds = true
    shimmerImageView.clipsToBounds = true

    shimmerImageView.layer.mask = gradientLayer
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    gradientLayer.frame = bounds
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    image = placeholderImage
    shimmerImageView.image = placeholderImage
  }
}
