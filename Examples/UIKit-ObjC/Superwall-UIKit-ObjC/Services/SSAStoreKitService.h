//
//  SSAStoreKitService.h
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/1/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const SSAStoreKitServiceDidUpdateSubscribedState;

@class SKProduct;
typedef NS_ENUM(NSInteger, SKPaymentTransactionState);

typedef void (^PurchaseCompletionHandler)(SKPaymentTransactionState state, NSError * _Nullable error);

/// Barebones example service responsible for interfacing directly with StoreKit. If you're using an SDK like RevenueCat, you'd replace this service here.
@interface SSAStoreKitService : NSObject

/// Provides the current subscription state. Observe notifications for `SSAStoreKitServiceDidUpdateSubscribedState` to be informed of updates to this property.
@property (nonatomic, assign, readonly, getter=isSubscribed) BOOL subscribed;

+ (SSAStoreKitService *)sharedService;

/// Purchases the provided `SKProduct` instance and provides a completion block with the resulting state and optional error.
- (void)purchaseProduct:(SKProduct *)product withCompletion:(nullable PurchaseCompletionHandler)completion;

/// Restores purchases.
- (BOOL)restorePurchases;

/// Forces the subscribe state to be updated.
- (void)updateSubscribedState;

@end

NS_ASSUME_NONNULL_END
