//
//  File.swift
//  
//
//  Created by brian on 7/21/21.
//

import WebKit
import UIKit
import Foundation

internal class WebPaywallViewController: UIViewController {
    
    public override func viewDidLoad() {
        self.view.addSubview(webview)
        NSLayoutConstraint.activate([
            webview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webview.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            webview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
        ])
        DispatchQueue.main.async { [self]
            let url = URL(string: "https://app.fitnessai.com/signup/?paywall=true&user_id=1234")!
            self.webview.load(URLRequest(url: url))
        }   
    }

    lazy var webview: WKWebView = {

       let config = WKWebViewConfiguration()
       config.allowsInlineMediaPlayback = true
       config.allowsAirPlayForMediaPlayback = true
       config.allowsPictureInPictureMediaPlayback = true
        config.userContentController.add(self, name: "paywallMessageHandler")

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
        
//    let contentController = self.webView.configuration.userContentController
//    contentController.add(self, name: "toggleMessageHandler")
//       wv.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
//       wv.isHidden = true
//       wv.navigationDelegate = self

       return wv
   }()
}

extension WebPaywallViewController: WKScriptMessageHandler
{
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard let dict = message.body as? [String : AnyObject] else {
            return
        }
        print("dict", dict)
    }
}
