//
//  SWWebView.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation
import WebKit

final class SWWebView: WKWebView {
  private var wkConfig: WKWebViewConfiguration = {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.allowsAirPlayForMediaPlayback = true
    config.allowsPictureInPictureMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []

    let preferences = WKPreferences()
    if #available(iOS 15.0, *) {
      if !DeviceHelper.shared.isMac {
        preferences.isTextInteractionEnabled = false // ignore-xcode-12
      }
    }
    preferences.javaScriptCanOpenWindowsAutomatically = true
    config.preferences = preferences
    return config
  }()

  init(delegate: WebEventDelegate) {
    wkConfig.userContentController.add(
      LeakAvoider(delegate: delegate),
      name: "paywallMessageHandler"
    )
    super.init(
      frame: .zero,
      configuration: wkConfig
    )

    translatesAutoresizingMaskIntoConstraints = false
    allowsBackForwardNavigationGestures = true
    allowsLinkPreview = false
    backgroundColor = .clear
    scrollView.maximumZoomScale = 1.0
    scrollView.minimumZoomScale = 1.0
    isOpaque = false

    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.bounces = true
    scrollView.contentInset = .zero
    scrollView.scrollIndicatorInsets = .zero
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.maximumZoomScale = 1.0
    scrollView.minimumZoomScale = 1.0
    scrollView.backgroundColor = .clear
    scrollView.isOpaque = false
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
