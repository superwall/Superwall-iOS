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
    
    init?(viewController: UIViewController, completion: ((PaywallPresentationResult) -> Void)? = nil) {
        self._viewController = viewController;
        self._completion = completion;
        super.init(nibName: nil, bundle: nil)
    };
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var _viewController: UIViewController;
    private var _completion: ((PaywallPresentationResult) -> Void)?;
    private var _complete = false;
    

    public func presentPaywall() {
        self._viewController.present(self, animated: true, completion: nil)
    };
    
    
    internal func complete(_ completionResult: PaywallPresentationResult) {
        if (!_complete && (_completion != nil)){
            self._complete = true
            self._completion?(completionResult);
        }
    };
    
    
    public override func viewDidLoad() {
        self.view.addSubview(webview)
        NSLayoutConstraint.activate([
            webview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webview.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            webview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
        ])
        DispatchQueue.main.async { [self]
//            let url = URL(string: "https://app.fitnessai.com/signup/?paywall=true&user_id=1234")!
            let url = URL(string: "http://192.168.1.96:8080?a=" + String(Int.random(in: 1...1000)))!
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
        log("userContentController - start")
        
        guard let bodyString = message.body as?  String else {
            log("unable to convert WKScriptMessage.body to string")
            return;
        }
        
        log("body string", bodyString)
        
        guard let bodyData = bodyString.data(using: .utf8) else {
            log("unable to convert bodyString to body data")
            return;
        }

        guard let wrappedPaywallEvents = try? JSONDecoder().decode(WrappedPaywallEvents.self, from: bodyData) else {
            log("failed to parse bodyString to WrappedPaywallEvent")
            return;
        }
        
        log("body struct", wrappedPaywallEvents)
        
        let events = wrappedPaywallEvents.payload.events;

        
        events.forEach { (event) in
            self.handleEvent(event: event)
        }
        
        log("userContentController - end")
    }
}

//MARK: Event Handler

extension WebPaywallViewController {
    
    func handleEvent(event: PaywallEvent)
    {
        log("handleEvent", event)
    
        switch (event) {
        case .Close:
            complete(.Closed)
            self.dismiss(animated: true)
            
            break;
        case .OpenURL(let url):
            complete(.OpenedURL(url: url))
            UIApplication.shared.openURL(url)
            break;
        case .OpenDeepLink(let url):
            complete(.OpenedDeepLink(url: url))
            // TODO: Handle deep linking
            break;
        case .Restore:
            let alert = UIAlertController.init(title: "Restore", message: "You selected to restore purchase", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "OK",
                    style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            complete(.InitiateResotre)
            self.present(alert, animated: true)
        default:
            break;
        }
    }
}
