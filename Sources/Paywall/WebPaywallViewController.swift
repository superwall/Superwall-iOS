//
//  File.swift
//  
//
//  Created by brian on 7/21/21.
//

import WebKit
import UIKit
import Foundation

class WebPaywallViewController: UIViewController {
    
    override func viewDidLoad() {
        NSLayoutConstraint.activate([
            webview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webview.topAnchor.constraint(equalTo: view.bottomAnchor, constant: 12),
            webview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
        ])
        
        let url = URL(string: "http://app.fitnessai.com/signup/?paywall=true&user_id=1234")!
        webview.load(URLRequest(url: url))
    }
    
//    let navbarStackView: UIStackView = {
//        let view = UIStackView()
//        view.axis = .horizontal
//        view.alignment = .center
//        view.distribution = .fill
//        view.spacing = 10
//        view.tag = 7676
//        view.translatesAutoresizingMaskIntoConstraints = false
//        return view
//    }()

    lazy var webview: WKWebView = {

       let config = WKWebViewConfiguration()
       config.allowsInlineMediaPlayback = true
       config.allowsAirPlayForMediaPlayback = true
       config.allowsPictureInPictureMediaPlayback = true

       let wv = WKWebView(frame: CGRect(), configuration: config)
       wv.translatesAutoresizingMaskIntoConstraints = false
       wv.allowsBackForwardNavigationGestures = true
       wv.allowsLinkPreview = false
        if #available(iOS 11.0, *) {
            wv.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
       wv.scrollView.contentInset = .init(top: 0, left: 0, bottom: 120, right: 0)
       wv.scrollView.bounces = true
       wv.scrollView.scrollIndicatorInsets = .zero
       wv.scrollView.showsVerticalScrollIndicator = false
       wv.scrollView.showsHorizontalScrollIndicator = false
       wv.backgroundColor = .clear
       wv.scrollView.backgroundColor = .clear
       wv.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
       wv.isHidden = true
       wv.navigationDelegate = self

       return wv

   }()
    
    
}

extension WebPaywallViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
//        if let url = webview.url?.absoluteString {
//            if url.contains("://checkout.stripe.com/pay/".green("checkout-page-url")) {
//
//                Analytics.shared.track("Transaction Began", self.analyticsProperties)
//
//                UIView.animate(withDuration: 0.2, delay: 0, options: .allowUserInteraction, animations: {
//                    self.webview.alpha = 0
//                }, completion: {
//                    _ in
//                    webView.scrollView.contentInset = .init(top: -64, left: 0, bottom: 120, right: 0)
//                    webView.scrollView.bounces = false
//                })
//
//            } else {
//                webView.scrollView.contentInset = .init(top: 0, left: 0, bottom: 120, right: 0)
//                webview.scrollView.bounces = true
//            }
//
//            if url.contains("success=true".green("checkout-page-payment-success")) {
//                Intercom.setInAppMessagesVisible(true)
//                Analytics.shared.track("Transaction Completed", self.analyticsProperties)
//                self.user.logCustomStartTrialWithFacebook(price: 52.00, isMonthly: false)
//                RootViewController.shared.markPayingUserAndReload(payingUser: true)
//            }
//
//        }

    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        if let url = webview.url?.absoluteString {
//            if url.contains("://checkout.stripe.com/pay/".green("checkout-page-url")) {
////                webView.scrollView.contentInset = .init(top: -64, left: 0, bottom: 120, right: 0)
////                webview.scrollView.bounces = false
//            } else {
//                webView.scrollView.contentInset = .init(top: 0, left: 0, bottom: 120, right: 0)
//                webview.scrollView.bounces = true
//            }
//        }
//
//        UIView.animate(withDuration: 0.5, animations: {
//
//            self.webview.alpha = 1.0
//
//        })
//
//        activityIndicator.stopAnimating()

    }
}
