//
//  SSASuperwallService.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/3/22.
//

#import "SSASuperwallService.h"

// services
#import "SSAStoreKitService.h"

// frameworks
@import SuperwallKit;
@import StoreKit;

#pragma mark - Constants

#warning For your own app you will need to use your own API key, available from the Superwall Dashboard
NSString *const kDemoAPIKey = @"pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9";
NSString *const kDemoUserId = @"abc";
NSString *const kUserAttributesFirstNameKey = @"firstName";

#pragma mark - Inline transform

static inline SWKPurchaseResult SWKPurchaseResultFromTransactionState(SKPaymentTransactionState state, NSError *error) {
  switch (state) {
    case SKPaymentTransactionStatePurchased:
      return SWKPurchaseResultPurchased;
    case SKPaymentTransactionStateFailed:
      switch (error.code) {
        case SKErrorOverlayTimeout:
        case SKErrorPaymentCancelled:
        case SKErrorOverlayCancelled:
          return SWKPurchaseResultCancelled;
        default:
          return SWKPurchaseResultFailed;
      }
    case SKPaymentTransactionStateDeferred:
      return SWKPurchaseResultPending;
    default:
      return NSNotFound;
  }
}

#pragma mark - SSASuperwallService

@interface SSASuperwallService () <SWKSuperwallDelegate>

@property (nonatomic, assign) BOOL loggedIn;

@end

@implementation SSASuperwallService

+ (SSASuperwallService *)sharedService {
  static SSASuperwallService *sharedService = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedService = [SSASuperwallService new];
  });

  return sharedService;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    // Listen for changes to the subscription state.
    [[NSNotificationCenter defaultCenter] addObserverForName:SSAStoreKitServiceDidUpdateSubscribedState object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
      if ([SSAStoreKitService sharedService].isSubscribed) {
        [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusActive;
      } else {
        [Superwall sharedInstance].subscriptionStatus = SWKSubscriptionStatusInactive;
      }
    }];
  }

  return self;
}

#pragma mark - Public Properties

- (BOOL)isLoggedIn {
  return [Superwall sharedInstance].isLoggedIn;
}

- (nullable NSString *)name {
  return [Superwall sharedInstance].userAttributes[kUserAttributesFirstNameKey];
}

- (void)setName:(nullable NSString *)name {
  id userAttributeFirstName = name ? : [NSNull null];
  [[Superwall sharedInstance] setUserAttributesDictionary:@{ kUserAttributesFirstNameKey : userAttributeFirstName }];
}

#pragma mark - Public Methods

- (void)initialize {
  // Load the current subscription state.
  [[SSAStoreKitService sharedService] updateSubscribedState];

  // Configure Superwall.

  [Superwall configureWithApiKey:kDemoAPIKey delegate:self];
}

- (void)logInWithCompletion:(nullable void (^)(void))completion {
  [[Superwall sharedInstance] identifyWithUserId:kDemoAPIKey completionHandler:^(NSError * _Nullable error) {
    switch (error.code) {
      case SWKIdentityErrorMissingUserId:
        NSLog(@"The provided userId was empty");
        break;
      default:
        NSLog(@"An unknown error occurred: %@", error.localizedDescription);
        break;
    }

    if (completion) {
      completion();
    }
  }];
}

- (void)logOutWithCompletion:(nullable void (^)(void))completion {
  [[Superwall sharedInstance] resetWithCompletionHandler:completion];
}

- (void)handleDeepLinkWithURL:(NSURL *)URL {
  [[Superwall sharedInstance] handleDeepLink:URL];
}

#pragma mark - SuperwallDelegate

- (void)purchaseWithProduct:(SKProduct * _Nonnull)product completion:(void (^ _Nonnull)(enum SWKPurchaseResult, NSError * _Nullable))completion {
  [[SSAStoreKitService sharedService] purchaseProduct:product withCompletion:^(SKPaymentTransactionState state, NSError * _Nullable error) {

    // Determine the associated purchase result;
    SWKPurchaseResult purchaseResult = SWKPurchaseResultFromTransactionState(state, error);
    if (purchaseResult != NSNotFound) {
      if (completion) {
        completion(purchaseResult, error);
      }
    }
  }];
}

- (void)restorePurchasesWithCompletion:(void (^ _Nonnull)(BOOL))completion { 
  [[SSAStoreKitService sharedService] restorePurchases];
}

- (void)didTrackSuperwallEventInfo:(SWKSuperwallEventInfo *)info {
  NSLog(@"Analytics event called %@", @(info.event));

  // Uncomment the following if you want to track the different analytics events received from the paywall:

//  switch (info.event) {
//    case SWKSuperwallEventFirstSeen:
//      <#code#>
//      break;
//    case SWKSuperwallEventAppOpen:
//      <#code#>
//      break;
//    case SWKSuperwallEventAppLaunch:
//      <#code#>
//      break;
//    case SWKSuperwallEventAppInstall:
//      <#code#>
//      break;
//    case SWKSuperwallEventSessionStart:
//      <#code#>
//      break;
//    case SWKSuperwallEventAppClose:
//      <#code#>
//      break;
//    case SWKSuperwallEventDeepLink:
//      <#code#>
//      break;
//    case SWKSuperwallEventTriggerFire:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallOpen:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallClose:
//      <#code#>
//      break;
//    case SWKSuperwallEventTransactionStart:
//      <#code#>
//      break;
//    case SWKSuperwallEventTransactionFail:
//      <#code#>
//      break;
//    case SWKSuperwallEventTransactionAbandon:
//      <#code#>
//      break;
//    case SWKSuperwallEventTransactionComplete:
//      <#code#>
//      break;
//    case SWKSuperwallEventSubscriptionStart:
//      <#code#>
//      break;
//    case SWKSuperwallEventFreeTrialStart:
//      <#code#>
//      break;
//    case SWKSuperwallEventTransactionRestore:
//      <#code#>
//      break;
//    case SWKSuperwallEventTransactionTimeout:
//      <#code#>
//      break;
//    case SWKSuperwallEventUserAttributes:
//      <#code#>
//      break;
//    case SWKSuperwallEventNonRecurringProductPurchase:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallResponseLoadStart:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallResponseLoadNotFound:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallResponseLoadFail:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallResponseLoadComplete:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallWebviewLoadStart:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallWebviewLoadFail:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallWebviewLoadComplete:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallWebviewLoadTimeout:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallProductsLoadStart:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallProductsLoadFail:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallProductsLoadComplete:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallPresentationFailInHoldout:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallPresentationFailNoPresenter:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallPresentationFailAlreadyPresented:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallPresentationFailDebuggerLaunched:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallPresentationFailNoRuleMatch:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallPresentationFailEventNotFound:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallPresentationFailUserIsSubscribed:
//      <#code#>
//      break;
//    case SWKSuperwallEventPaywallPresentationFailNoPaywallViewController:
//      <#code#>
//      break
//  }
}

@end
