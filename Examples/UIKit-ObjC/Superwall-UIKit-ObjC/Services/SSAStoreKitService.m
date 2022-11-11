//
//  SSAStoreKitService.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/1/22.
//

#import "SSAStoreKitService.h"

// frameworks
@import StoreKit;

/// Notification name for posting a change to the subscribe state.
NSNotificationName const SSAStoreKitServiceDidUpdateSubscribedState = @"SSAStoreKitServiceDidUpdateSubscribedState";

@interface SSAStoreKitService () <SKPaymentTransactionObserver>

@property (nonatomic, assign) BOOL subscribed;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PurchaseCompletionHandler> *completionHandlersByProductIdentifier;

@end

@implementation SSAStoreKitService

+ (SSAStoreKitService *)sharedService {
  static SSAStoreKitService *sharedService = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedService = [SSAStoreKitService new];
  });

  return sharedService;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.completionHandlersByProductIdentifier = [NSMutableDictionary dictionaryWithDictionary:@{}];
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
  }

  return self;
}

#pragma mark - Public

- (BOOL)purchaseProduct:(SKProduct *)product withCompletion:(nullable PurchaseCompletionHandler)completion {
  // For the simplicity of this sample app, we're only going to allow the purchase of the same product one at a time. More details here: https://www.revenuecat.com/blog/storekit-is-broken/
  BOOL transactionInProgress = [self.completionHandlersByProductIdentifier.allKeys containsObject:product.productIdentifier];

  if (transactionInProgress) {
    return NO;
  }

  if (completion) {
    // Add the completion handler for use in the delegate method later.
    [self.completionHandlersByProductIdentifier addEntriesFromDictionary:@{ product.productIdentifier : completion }];
  }

  SKPayment *payment = [SKPayment paymentWithProduct:product];
  [[SKPaymentQueue defaultQueue] addPayment:payment];

  return YES;
}

- (void)restorePurchases {
  [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)updateSubscribedState {
  [self restorePurchases];
}

#pragma mark - Private

- (void)setSubscribed:(BOOL)subscribed {
  BOOL currentSubscribed = _subscribed;

  _subscribed = subscribed;

  BOOL subscribedUpdated = (currentSubscribed != _subscribed);
  if (subscribedUpdated) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter] postNotificationName:SSAStoreKitServiceDidUpdateSubscribedState object:self];
    });
  }
}

- (void)paymentQueueDidFinishTransaction:(SKPaymentTransaction *)transaction subscribed:(BOOL)subscribed {
  // Get the completion handler associated with the product identifier (which we're using as a proxy for the transaction).
  NSString *productIdentifier = transaction.payment.productIdentifier;

  // Get the completion handler.
  PurchaseCompletionHandler completion = self.completionHandlersByProductIdentifier[productIdentifier];

  // Remove the completion handler.
  [self.completionHandlersByProductIdentifier removeObjectForKey:productIdentifier];

  // Clean up the transaction queue.
  [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

  // Change the subscribed state.
  self.subscribed = subscribed;

  // Execute the completion handler if one exists for this product identifier.
  if (completion) {
    completion(transaction.transactionState, transaction.error);
  }
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(nonnull SKPaymentQueue *)queue updatedTransactions:(nonnull NSArray<SKPaymentTransaction *> *)transactions {
  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction * _Nonnull transaction, NSUInteger idx, BOOL * _Nonnull stop) {

      // Change the subscribe state and perform clean up if needed.
      switch (transaction.transactionState) {
        case SKPaymentTransactionStateDeferred:
        case SKPaymentTransactionStatePurchasing:
          // no-op; these states precede the following transaction states.
          break;
        case SKPaymentTransactionStatePurchased:
        case SKPaymentTransactionStateRestored:
          [weakSelf paymentQueueDidFinishTransaction:transaction subscribed:YES];
          break;
        case SKPaymentTransactionStateFailed:
          [weakSelf paymentQueueDidFinishTransaction:transaction subscribed:NO];
          break;
        default:
          break;
      }
    }];
  });
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
  self.subscribed = NO;
}

@end
