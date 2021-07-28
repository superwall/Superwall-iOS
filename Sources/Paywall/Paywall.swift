import UIKit



public class Paywall {
    
    private let _apiKey: String?;
    private var _appUserId: String?;
    public static var debugLogsEnabled: Bool = false;
    public static var shared: Paywall = Paywall(apiKey: nil, appUserId: nil)
    
    // MARK: Initialization
    
    private init(apiKey: String?, appUserId: String?) {
        self._apiKey = apiKey;
        self._appUserId = appUserId;
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
        self._appUserId = appUserID;
        return self;
    }
    
    @discardableResult
    public func logout() -> Paywall {
        self._appUserId = nil;
        return self;
    }
    
    
    // MARK: Paywall Presentation
    public func presentPaywall(on viewController: UIViewController, completion: ((PaywallPresentationResult) -> Void)? = nil) {
        viewController.present(WebPaywallViewController(), animated: true, completion: nil)
    };
}
