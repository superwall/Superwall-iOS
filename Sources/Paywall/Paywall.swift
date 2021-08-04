import UIKit



public class Paywall {
    
    private(set) var apiKey: String?;
    private(set) var appUserId: String?;
    public static var debugLogsEnabled: Bool = false;
    public static var shared: Paywall = Paywall(apiKey: nil, appUserId: nil)
    
    private(set) var paywallLoaded: Bool = false;
    private(set) var paywallResponse: PaywallResponse?;
    
    private(set) var vc: WebPaywallViewController?;
    private(set) var view: UIView?;
    
    // MARK: Initialization
    
    private init(apiKey: String?, appUserId: String?) {
        self.apiKey = apiKey;
        self.appUserId = appUserId;
        
        Store.shared.apiKey = apiKey;
        Store.shared.appUserId = appUserId;
        
        // Fetch paywall
        let paywallRequest = PaywallRequest(userId: self.appUserId ?? "");
        Network.shared.paywall(paywallRequest: paywallRequest) { (result) in
            
            switch(result){
            case .success(let response):
                self.paywallResponse = response;
                DispatchQueue.main.async {
                    
                
                    
                    
                    self.vc = WebPaywallViewController(paywallResponse: response, completion: nil)
                    
                    if let v =  UIApplication.shared.keyWindow?.rootViewController {
                        v.addChild(self.vc!)
                        self.vc!.view.alpha = 0.01
                        v.view.insertSubview(self.vc!.view, at: 0)
                        self.vc!.didMove(toParent: v)
                    }
//                    self.vc?.modalPresentationStyle = .overFullScreen
//                    self.view = self.vc?.view
//                    self.vc?.view.alpha = 0.01
                    
//                    if let window = UIApplication.shared.keyWindow {
//                        self.vc?.webview.alpha = 0.01
//                        window.insertSubview(self.vc!.webview, at: 0)
//                    }
                    
//                    UIApplication.shared.keyWindow?.rootViewController!.present(self.vc!, animated: false, completion: {
//                        self.vc?.dismiss(animated: false) {
//                            self.view?.alpha = 1;
//                        }
//                    })
                    
                    
//                    self.vc?.loadViewIfNeeded()
//                    self.v
//                    self.view?.setNeedsLayout()
//                    self.vc?.loadView()
//                    self.vc?.viewDidLoad()
//                    self.vc?.loadView()
//                    self.vc?.didMove(toParent: nil)
                }
                
                break
            case .failure(let error):
                print("Error", error)
            }
            self.paywallLoaded = true;
        }
    }
    
    @discardableResult
    public static func configure(withAPIKey: String) -> Paywall {
        shared = Paywall(apiKey: withAPIKey, appUserId: nil);
        return shared;
    }
    
    @discardableResult
    public static func config(withAPIKey: String, appUserID: String) -> Paywall {
        shared = Paywall(apiKey: withAPIKey, appUserId: appUserID);
        return shared;
    }
    
    
    // MARK: Users
    @discardableResult
    public func login(appUserID: String) -> Paywall {
        self.appUserId = appUserID;
        return self;
    }
    
    @discardableResult
    public func logout() -> Paywall {
        self.appUserId = nil;
        return self;
    }
    
    // MARK: Paywall Presentation
    public func presentPaywall(on viewController: UIViewController? = UIApplication.shared.keyWindow?.rootViewController, completion: ((PaywallPresentationResult) -> Void)? = nil) {
        if (self.paywallLoaded && self.paywallResponse != nil && viewController != nil) {
//            let paywallVC = WebPaywallViewController(paywallResponse: self.paywallResponse!, viewController: viewController, completion: completion)
//            vc?.presentPaywall()
//            dispatch_sync_on_main_thread {
//                self.vc!.webview.removeFromSuperview()
//                self.vc?.view?.alpha = 1;
            
            self.vc!.willMove(toParent: nil)
            self.vc!.view.removeFromSuperview()
            self.vc!.removeFromParent()
            self.vc!.view.alpha = 1.0
                viewController!.present(self.vc!, animated: true, completion: nil)
//            }

        }
    };
}
