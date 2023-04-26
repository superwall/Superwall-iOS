//
//  SSASuperwallService.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/3/22.
//

#import "SSASuperwallService.h"

// frameworks
@import SuperwallKit;

#pragma mark - Constants

#warning For your own app you will need to use your own API key, available from the Superwall Dashboard
NSString *const kDemoAPIKey = @"pk_e6bd9bd73182afb33e95ffdf997b9df74a45e1b5b46ed9c9";
NSString *const kDemoUserId = @"abc";
NSString *const kUserAttributesFirstNameKey = @"firstName";

/// Notification name for posting a change to the subscribe state.
NSNotificationName const SSASuperwallServiceDidUpdateSubscribedState = @"SSASuperwallServiceDidUpdateSubscribedState";

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

#pragma mark - Public Properties

- (BOOL)isLoggedIn {
  return [Superwall sharedInstance].isLoggedIn;
}

- (nullable NSString *)name {
  return [Superwall sharedInstance].userAttributes[kUserAttributesFirstNameKey];
}

- (void)setName:(nullable NSString *)name {
  id userAttributeFirstName = name ? : [NSNull null];
  [[Superwall sharedInstance] setUserAttributes:@{ kUserAttributesFirstNameKey : userAttributeFirstName }];
}

#pragma mark - Public Methods

- (void)initialize {
  [Superwall configureWithApiKey:kDemoAPIKey];
  [[Superwall sharedInstance] setDelegate:self];
}

- (void)logIn {
  [[Superwall sharedInstance] identifyWithUserId:kDemoUserId];
}

- (void)logOut {
  [[Superwall sharedInstance] reset];
}

- (void)handleDeepLinkWithURL:(NSURL *)URL {
  [[Superwall sharedInstance] handleDeepLink:URL];
}

#pragma mark - SuperwallDelegate

- (void)subscriptionStatusDidChangeTo:(enum SWKSubscriptionStatus)newValue {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:SSASuperwallServiceDidUpdateSubscribedState object:self];
  });
}

- (void)handleSuperwallEventWithInfo:(SWKSuperwallEventInfo *)eventInfo {
  NSLog(@"Track this analytics event in your own system %@", @(eventInfo.event));
  
}

@end
