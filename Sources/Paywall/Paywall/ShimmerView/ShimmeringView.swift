//
//  ShimmeringView.swift
//  
//
//  Created by Jake Mor on 8/4/21.
//  From: https://github.com/BeauNouvelle/ShimmerSwift/blob/master/Shimmer/Shimmer.swift

import Foundation
#if canImport(UIKit)
import UIKit

final class ShimmeringView: UIView {
  override class var layerClass: Swift.AnyClass {
    return ShimmeringLayer.self
  }

  /// The content view to be shimmered
  var contentView = UIView() {
    didSet {
      if oldValue != contentView {
        addSubview(contentView)
        shimmerLayer?.contentLayer = contentView.layer
      }
    }
  }

  /// Set to `true` to start shimmer animation, and `false` to stop. Detaults to `false`.
  var isShimmering = false {
    didSet { shimmerLayer?.isShimmering = isShimmering }
  }

  /// The speed of the shimmer animation in points per second. The higher the number, the faster the animation.
  /// Defaults to 230.
  var shimmerSpeed: CGFloat = 230.0 {
    didSet { shimmerLayer?.shimmerSpeed = shimmerSpeed }
  }

  /// The highlight length of the shimmer. Range of [0,1], defaults to 1.0.
  var shimmerHighlightLength: CGFloat = 1.0 {
    didSet { shimmerLayer?.shimmerHighlightLength = shimmerHighlightLength }
  }

  /// The direction of the shimmer animation.
  /// Defaults to `.right`, which will run the animation from left to right.
  var shimmerDirection: Shimmer.Direction = .right {
    didSet { shimmerLayer?.updateShimmering() }
  }

  /// The time interval between shimmers in seconds.
  /// Defaults to 0.4.
  var shimmerPauseDuration: CFTimeInterval = 0.25 {
    didSet { shimmerLayer?.shimmerPauseDuration = shimmerPauseDuration }
  }

  /// The opacity of the content during a shimmer. Defaults to 0.5.
  var shimmerAnimationOpacity: CGFloat = 0.25 {
    didSet { shimmerLayer?.shimmerAnimationOpacity = shimmerAnimationOpacity }
  }

  /// The opacity of the content when not shimmering. Defaults to 1.0.
  var shimmerOpacity: CGFloat = 1.0 {
    didSet { shimmerLayer?.shimmerOpacity = shimmerOpacity }
  }

  /// The absolute CoreAnimation media time when the shimmer will begin.
  var shimmerBeginTime: CFTimeInterval = .greatestFiniteMagnitude {
    didSet { shimmerLayer?.shimmerBeginTime = shimmerBeginTime }
  }

  /// The duration of the fade used when the shimmer begins. Defaults to 0.1.
  var shimmerBeginFadeDuration: CFTimeInterval = 0.2 {
    didSet { shimmerLayer?.shimmerBeginFadeDuration = shimmerBeginFadeDuration }
  }

  /// The duration of the fade used when the shimmer ends. Defaults to 0.3.
  var shimmerEndFadeDuration: CFTimeInterval = 0.2 {
    didSet { shimmerLayer?.shimmerEndFadeDuration = shimmerEndFadeDuration }
  }

  /// The absolute CoreAnimation media time when the shimmer will fade in.
  var shimmerFadeTime: CFTimeInterval? {
    didSet { shimmerLayer?.shimmerFadeTime = shimmerFadeTime }
  }

  override func layoutSubviews() {
    contentView.bounds = self.bounds
    contentView.center = self.center
    super.layoutSubviews()
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  private var shimmerLayer: ShimmeringLayer? {
    return (layer as? ShimmeringLayer)
  }
}
#endif
