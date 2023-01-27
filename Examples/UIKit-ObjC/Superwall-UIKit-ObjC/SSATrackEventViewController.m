//
//  SSATrackEventViewController.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/4/22.
//

#import "SSATrackEventViewController.h"

// frameworks
@import SuperwallKit;

// services
#import "SSAStoreKitService.h"
#import "SSASuperwallService.h"

@interface SSATrackEventViewController ()

@property (nonatomic, strong) IBOutlet UILabel *subscriptionLabel;

@end

@implementation SSATrackEventViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Configure the navigation bar.
  self.navigationItem.hidesBackButton = YES;

  // Update for current subscription state.
  [self updateForSubscriptionState:[SSAStoreKitService sharedService].isSubscribed];

  // Listen for changes to the subscription state.
  __weak typeof(self) weakSelf = self;
  [[NSNotificationCenter defaultCenter] addObserverForName:SSAStoreKitServiceDidUpdateSubscribedState object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
    [weakSelf updateForSubscriptionState:[SSAStoreKitService sharedService].isSubscribed];
  }];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
}

#pragma mark - Actions

- (IBAction)trackEvent:(id)sender {
  __weak typeof(self) weakSelf = self;
  [[Superwall sharedInstance] trackWithEvent:@"MyEvent"
                     params:nil
                   products:nil
   ignoreSubscriptionStatus:NO
  presentationStyleOverride:SWKPaywallPresentationStyleNone
                     onSkip:^(enum SWKPaywallSkippedReason reason, NSError * _Nullable error) {
    [weakSelf paywallSkippedWithReason:reason error:error];
  }
                  onPresent:^(SWKPaywallInfo * _Nonnull paywallInfo) {
    [weakSelf paywallPresentedWithPaywallInfo:paywallInfo];
  }
                  onDismiss:^(enum SWKPaywallDismissedResultState dismissedResultState, NSString * _Nullable productIdentifier, SWKPaywallInfo * _Nonnull paywallInfo) {
    [weakSelf paywallDismissedWithResultState:dismissedResultState productIdentifier:productIdentifier paywallInfo:paywallInfo];
  }];
}

- (IBAction)logOut:(id)sender {
  __weak typeof(self) weakSelf = self;
  [[SSASuperwallService sharedService] logOutWithCompletion:^{
    [weakSelf.navigationController popToRootViewControllerAnimated:YES];
  }];
}

#pragma mark - Private

- (void)updateForSubscriptionState:(BOOL)isSubscribed {
  if (isSubscribed) {
    self.subscriptionLabel.text = @"You currently have an active subscription. Therefore, the paywall will never show. For the purposes of this app, delete and reinstall the app to clear subscriptions.";
  } else {
    self.subscriptionLabel.text = @"You do not have an active subscription so the paywall will show when clicking the button.";
  }
}

#pragma mark - Event tracking

- (void)paywallSkippedWithReason:(enum SWKPaywallSkippedReason)reason error:(nullable NSError *)error {
  switch (reason) {
    case SWKPaywallSkippedReasonHoldout:
      NSLog(@"The user is in a holdout group. %@", error.localizedDescription);
      break;
    case SWKPaywallSkippedReasonNoRuleMatch:
      NSLog(@"The user did not match any rules");
      break;
    case SWKPaywallSkippedReasonEventNotFound:
      NSLog(@"The event wasn't found in a campaign on the dashboard.");
      break;
    case SWKPaywallSkippedReasonError:
      NSLog(@"Failed to present paywall. Consider a native paywall fallback. %@", error.localizedDescription);
      break;
    case SWKPaywallSkippedReasonUserIsSubscribed:
      NSLog(@"The user is subscribed. %@", error.localizedDescription);
      break;
  }
}

- (void)paywallPresentedWithPaywallInfo:(SWKPaywallInfo *)paywallInfo {
  NSLog(@"Paywall info is %@", paywallInfo);
}

- (void)paywallDismissedWithResultState:(enum SWKPaywallDismissedResultState)dismissedResultState productIdentifier:(nullable NSString *)productIdentifier paywallInfo:(SWKPaywallInfo *)paywallInfo {
  switch (dismissedResultState) {
    case SWKPaywallDismissedResultStatePurchased:
      NSLog(@"The purchased product ID is %@.", productIdentifier);
      break;
    case SWKPaywallDismissedResultStateClosed:
      NSLog(@"The paywall was closed.");
      break;
    case SWKPaywallDismissedResultStateRestored:
      NSLog(@"The product was restored.");
      break;
  }
}

@end
