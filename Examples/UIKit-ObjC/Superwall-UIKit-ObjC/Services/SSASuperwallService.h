//
//  SSASuperwallService.h
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Responsible for providing a convenient means of interacting with some Superwall functionality, and for communicating with the transaction service. In this demo, the underlying transaction service is StoreKit, but you might consider replacing with a third-party SDK like RevenueCat.
@interface SSASuperwallService : NSObject

/// Convenience to determine the logged in status of the user.
@property (nonatomic, assign, readonly, getter=isLoggedIn) BOOL loggedIn;

/// Convenience to get or set the name of the user on Superwall's user attributes.
@property (nonatomic, copy, nullable) NSString *name;

+ (SSASuperwallService *)sharedService;

/// Initialize the `SSASuperwallService` instance as early as possible.
- (void)initialize;

/// Simplified abstraction over `Superwall` login functionality.
- (void)logInWithCompletion:(nullable void (^)(void))completion;

/// Simplified abstraction over `Superwall` logout functionality.
- (void)logOutWithCompletion:(nullable void (^)(void))completion;

/// Simplified abstraction over `Superwall` deeplink functionality.
- (void)handleDeepLinkWithURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
