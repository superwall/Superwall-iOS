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
    
    init?(paywallResponse: PaywallResponse,
//          viewController: UIViewController,
          completion: ((PaywallPresentationResult) -> Void)? = nil) {
        self._paywallResponse =  paywallResponse;
//        self._viewController = viewController;
        self._completion = completion;
        super.init(nibName: nil, bundle: nil)
        
    
        
        DispatchQueue.main.async { [self]


            
            
            
//            let url = URL(string: "https://app.fitnessai.com/signup/?paywall=true&user_id=1234")!
//            let url = URL(string: "http://192.168.1.96:8080?a=" + String(Int.random(in: 1...1000)))!
//            let url = URL(string: "https://paywalrus-example-paywall.netlify.app")!
            let url = URL(string: self._paywallResponse.url)

//                        self.webview.load(URLRequest(url: url!))
            
//            self.webview.layoutSubviews()

        
//            self.webview.loadHTMLString(paywall, baseURL: URL(string: paywallResponse.url)!)
            self.view.backgroundColor = UIColor(hexString: "#181A1F");
        }
    };
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var _paywallResponse: PaywallResponse;
//    private var _viewController: UIViewController;
    private var _completion: ((PaywallPresentationResult) -> Void)?;
    private var _complete = false;
    

//    public func presentPaywall() {
//        self._viewController.present(self, animated: true, completion: nil)
//    };
    
    
    internal func complete(_ completionResult: PaywallPresentationResult) {
        if (!_complete && (_completion != nil)){
            self._complete = true
            self._completion?(completionResult);
        }
    };
    
    
    public override func viewDidLoad() {
        self.view.addSubview(self.contentPlaceholderImageView)

        NSLayoutConstraint.activate([

            self.contentPlaceholderImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.contentPlaceholderImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.contentPlaceholderImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.contentPlaceholderImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)

        ])
        self.view.addSubview(self.webview)
        self.webview.isHidden = true
        
        NSLayoutConstraint.activate([
            self.webview.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.webview.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.webview.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 12),
            self.webview.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0),
        ])
 
    }

    
    
    public override func viewWillAppear(_ animated: Bool) {

    }
   var contentPlaceholderImageView: UIImageView = {
//    let imageView = UIImageView(image: UIImage(named: "paywall_placeholder", in: Bundle.module, compatibleWith: nil)!)
    
    if #available(iOS 13.0, *) {
        let imageView = UIImageView(image: UIImage(systemName: "play.circle.fill")?.withRenderingMode(.alwaysTemplate))

            imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .red
            imageView.backgroundColor = .clear
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.isHidden = false
            imageView.alpha = 0.2
            
            return imageView
        
    }
    
    return UIImageView()
        }()
    
    lazy var webview: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.userContentController.add(self, name: "paywallMessageHandler")
        
//        config.suppressesIncrementalRendering = true

       let wv = WKWebView(frame: CGRect(), configuration: config)
       wv.translatesAutoresizingMaskIntoConstraints = false
       wv.allowsBackForwardNavigationGestures = true
       wv.allowsLinkPreview = false
        if #available(iOS 11.0, *) {
            wv.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        wv.scrollView.bounces = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.contentInset = .init(top: 0, left: 0, bottom: 120, right: 0)
        wv.scrollView.scrollIndicatorInsets = .zero
        wv.scrollView.showsVerticalScrollIndicator = false
        wv.scrollView.showsHorizontalScrollIndicator = false
        wv.scrollView.backgroundColor = .clear
        wv.backgroundColor = .clear
        wv.isOpaque = false
        
        wv.scrollView.isOpaque = false
        
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

struct TemplateSubstitutions: Codable {
    var event_name: String
    var substitutions: [String: String]
}
//MARK: Event Handler

extension WebPaywallViewController {
    
    func handleEvent(event: PaywallEvent)
    {
        log("handleEvent", event)
    
        switch (event) {
        case .Ping:
        
            let subs = self._paywallResponse.substitutions.reduce([String: String]()) { (dict, sub) -> [String: String] in
                var dict = dict
                dict[sub.key] = sub.value
                return dict
            }
            let subsEvent = TemplateSubstitutions(event_name: "template_substitutions", substitutions: subs)
            let eventData = try? JSONEncoder().encode(subsEvent)
            let eventString = eventData != nil ? String(data: eventData!, encoding: .utf8) ?? "{}" : "{}"
            let scriptSrc = """
                window.paywall.accept(JSON.parse('\(eventString)'))
            """
            print("sriptSrc", scriptSrc)
            self.webview.evaluateJavaScript(scriptSrc) { (result, error) in
                if let result = result {
                    print("Label is updated with message: \(result)")
                } else if let error = error {
                    print("An error occurred: \(error)")
                }
                if #available(iOS 14.0, *) {
                    self.webview.createPDF { (result) in
                        print(result)
                    }
                } else {
                    // Fallback on earlier versions
                }
            }

            break;
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
