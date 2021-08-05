import UIKit
import Foundation

@objc public protocol PaywallDelegate: AnyObject {
    
    func userDidInitiateCheckout(forProductWithId id: String, purchaseCompleted: () -> (), checkoutAbandoned: () -> (), errorOccurred: (NSError) -> ())
    func userDidInitiateRestore(restoreSucceeded: (Bool) -> ())
    
    @objc optional func willDismissPaywall()
    @objc optional func willPresentPaywall()

    @objc optional func didDismissPaywall()
    @objc optional func didPresentPaywall()
    
    @objc optional func willOpenURL(url: URL)
    @objc optional func willOpenDeepLink(url: URL)

}

public class Paywall {
    
    public static var debugLogsEnabled: Bool = false
    public static var shared: Paywall = Paywall(apiKey: nil, appUserId: nil)
    
    private(set) var apiKey: String?
    private(set) var appUserId: String?
    
    private(set) var paywallLoaded: Bool = false
    private(set) var paywallResponse: PaywallResponse?
    
    private(set) var paywallViewController: PaywallViewController?
    
    private typealias WhenReadyCompletionBlock = () -> ()
    private var whenReadyCompletionBlocks: [WhenReadyCompletionBlock] = []
    
//    public typealias PurchaseDidEndCompletionBlock: () -> Bool
    
    public static var delegate: PaywallDelegate? = nil
    
    // MARK: Initialization
    
    private init(apiKey: String?, appUserId: String?) {
        self.apiKey = apiKey
        self.appUserId = appUserId
        
        Store.shared.apiKey = apiKey
        Store.shared.appUserId = appUserId
        
        // Fetch paywall
        let paywallRequest = PaywallRequest(userId: self.appUserId ?? "")
        Network.shared.paywall(paywallRequest: paywallRequest) { (result) in
            
            switch(result){
            case .success(let response):
                self.paywallResponse = response
                DispatchQueue.main.async {
                    
                    self.paywallViewController = PaywallViewController(paywallResponse: response, completion: self.paywallEventDidOccur)
                    
                    if let v =  UIApplication.shared.keyWindow?.rootViewController {
                        v.addChild(self.paywallViewController!)
                        self.paywallViewController!.view.alpha = 0.01
                        v.view.insertSubview(self.paywallViewController!.view, at: 0)
                        self.paywallViewController!.view.transform = CGAffineTransform(translationX: 1000, y: 0)
                        self.paywallViewController!.didMove(toParent: v)
                    }
                    
                    self.whenReadyCompletionBlocks.forEach({$0()})
                    self.whenReadyCompletionBlocks.removeAll()

                }
                
                break
            case .failure(let error):
                print("Error", error)
            }
            self.paywallLoaded = true
        }
    }
    
    @discardableResult
    public static func configure(withAPIKey: String) -> Paywall {
        shared = Paywall(apiKey: withAPIKey, appUserId: nil)
        return shared
    }
    
    @discardableResult
    public static func config(withAPIKey: String, appUserID: String) -> Paywall {
        shared = Paywall(apiKey: withAPIKey, appUserId: appUserID)
        return shared
    }
    
    
    // MARK: Users
    @discardableResult
    public func login(appUserID: String) -> Paywall {
        self.appUserId = appUserID
        return self
    }
    
    @discardableResult
    public func logout() -> Paywall {
        self.appUserId = nil
        return self
    }
    
    
    // helper func, closure only called after .success in init
    private func whenReady(_ block: @escaping WhenReadyCompletionBlock) {
        if paywallLoaded {
            block()
        } else {
            whenReadyCompletionBlocks.append(block)
        }
    }
    
    // we can make this overridable one day?
    private func paywallEventDidOccur(result: PaywallPresentationResult) {
        
        switch result {
        case .closed:
            _dismiss()
        case .initiatePurchase(let productId):
//            Paywall.delegate?.userDidInitiateCheckout(forProductWithId: productId, purchaseSucceeded: { success in
//                if success {
//                    _purchaseDidSucceed(forProductWithId: productId)
//                } else {
//                    _purchaseWasAbandoned(forProductWithId: productId)
//                }
//            })
            
            
            Paywall.delegate?.userDidInitiateCheckout(forProductWithId: productId, purchaseCompleted: {
                _purchaseDidSucceed(forProductWithId: productId)
            }, checkoutAbandoned: {
                _checkoutWasAbandoned(forProductWithId: productId)
            }, errorOccurred: { error in
                _purchaseErrorDidOccur(error: error, forProductWithId: productId)
            })
        case .initiateResotre:
            Paywall.delegate?.userDidInitiateRestore(restoreSucceeded: { success in
                if success {
                    _restoreDidSucceed()
                } else {
                    _restoreDidFail()
                }
            })
        case .openedURL(let url):
            Paywall.delegate?.willOpenURL?(url: url)
        case .openedDeepLink(let url):
            Paywall.delegate?.willOpenDeepLink?(url: url)
        }
    }
    
    // purchase callbacks
    private func _purchaseDidSucceed(forProductWithId productId: String) {
        // TODO: ANALYTICS
        _dismiss()
    }
    
    private func _purchaseErrorDidOccur(error: NSError, forProductWithId productId: String) {
        // TODO: ANALYTICS
        
    }
    
    private func _checkoutWasAbandoned(forProductWithId productId: String) {
        // TODO: ANALYTICS
        
    }

    // restore callbacls
    private func _restoreDidSucceed() {
        // TODO: ANALYTICS
        _dismiss()
    }

    private func _restoreDidFail() {
        // TODO: ANALYTICS
        
    }

    
    private func _dismiss() {
        Paywall.delegate?.willDismissPaywall?()
        paywallViewController?.dismiss(animated: true, completion: {
            Paywall.delegate?.didDismissPaywall?()
        })
    }
    
    private static func _present( on presentOn: UIViewController? = nil) {

        if (shared.paywallLoaded) {
            
            guard let delegate = delegate else {
                fatalError("Yikes ... you need to set Paywall.delegate equal to a PaywallDelegate before doing anything fancy")
            }
            
            guard let presentor = (presentOn ?? UIApplication.shared.keyWindow?.rootViewController) else {
                fatalError("No UIViewController to present paywall on. This usually happens when you call this method before a window was made key and visible. Try calling this a little later, or explicitly pass in a UIViewController to present your Paywall on :)")
            }
            
            guard let vc = shared.paywallViewController else {
                fatalError("Paywall's viewcontroller is nil!")
            }
            
            guard let _ = shared.paywallResponse else {
                fatalError("Paywall presented before API response was received")
            }
            
            if !vc.isBeingPresented {
                vc.willMove(toParent: nil)
                vc.view.removeFromSuperview()
                vc.removeFromParent()
                vc.view.alpha = 1.0
                vc.view.transform = .identity
                vc.webview.scrollView.contentOffset = CGPoint.zero
                delegate.willPresentPaywall?()
                presentor.present(vc, animated: true, completion: {
                    delegate.didPresentPaywall?()
                })
            }
            
        }
        
    }
    
    // MARK: Paywall Presentation
    
    public static func present(on viewController: UIViewController? = nil) {
        shared.whenReady {
            _present(on: viewController)
        }
    }
}
