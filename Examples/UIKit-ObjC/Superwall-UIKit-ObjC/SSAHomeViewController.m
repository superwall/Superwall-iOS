//
//  SSAHomeViewController.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/4/22.
//

#import "SSAHomeViewController.h"

// App Delegate
#import "SSAAppDelegate.h"

// frameworks
@import SuperwallKit;

@interface SSAHomeViewController ()

@property (nonatomic, strong) IBOutlet UILabel *subscriptionLabel;

@end

@implementation SSAHomeViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Configure the navigation bar.
  self.navigationItem.hidesBackButton = YES;

  // Update for current subscription state.
  [self updateForSubscriptionState:Superwall.sharedInstance.subscriptionStatus];

  // Listen for changes to the subscription state.
  __weak typeof(self) weakSelf = self;
  [[NSNotificationCenter defaultCenter] addObserverForName:SSAAppDelegateDidUpdateSubscribedState object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
    [weakSelf updateForSubscriptionState:Superwall.sharedInstance.subscriptionStatus];
  }];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
}

#pragma mark - Actions

- (IBAction)registerPlacement:(id)sender {
  SWKPaywallPresentationHandler *handler = [[SWKPaywallPresentationHandler alloc] init];

  [handler onDismiss:^(SWKPaywallInfo * _Nonnull paywallInfo) {
    NSLog(@"The paywall dismissed. PaywallInfo: %@", paywallInfo);
  }];

  [handler onPresent:^(SWKPaywallInfo * _Nonnull paywallInfo) {
    NSLog(@"The paywall presented. PaywallInfo: %@", paywallInfo);
  }];

  [handler onSkip:^(enum SWKPaywallSkippedReason reason) {
    switch (reason) {
      case SWKPaywallSkippedReasonUserIsSubscribed:
        NSLog(@"Paywall not shown because user is subscribed.");
        break;
      case SWKPaywallSkippedReasonHoldout:
        NSLog(@"Paywall not shown because user is in a holdout group.");
        break;
      case SWKPaywallSkippedReasonNoRuleMatch:
        NSLog(@"Paywall not shown because user doesn't match any rules.");
        break;
      case SWKPaywallSkippedReasonEventNotFound:
        NSLog(@"Paywall not shown because this event isn't part of a campaign.");
        break;
      case SWKPaywallSkippedReasonNone:
        // The paywall wasn't skipped.
        break;
    }
  }];

  [handler onError:^(NSError * _Nonnull error) {
    NSLog(@"The paywall presentation failed with error %@", error);
  }];

  [[Superwall sharedInstance] registerWithPlacement:@"campaign_trigger" params:nil handler:handler feature:^{
    UIAlertController* alert = [UIAlertController
      alertControllerWithTitle:@"Feature Launched"
      message:@"Wrap your awesome features in register calls like this to remotely paywall your app. You can remotely decide whether these are paid features."
      preferredStyle:UIAlertControllerStyleAlert
    ];

    UIAlertAction* okAction = [UIAlertAction
      actionWithTitle:@"OK"
      style:UIAlertActionStyleDefault
      handler:^(UIAlertAction * action) {}
    ];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
  }];
}

- (IBAction)logOut:(id)sender {
  [[Superwall sharedInstance] reset];
  [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark - Private

- (void)updateForSubscriptionState:(SWKSubscriptionStatus)status {
  switch (status) {
    case SWKSubscriptionStatusActive:
      self.subscriptionLabel.text = @"You currently have an active subscription. Therefore, the paywall will never show. For the purposes of this app, delete and reinstall the app to clear subscriptions.";
      break;
    case SWKSubscriptionStatusInactive:
      self.subscriptionLabel.text = @"You do not have an active subscription so the paywall will show when clicking the button.";
      break;
    case SWKSubscriptionStatusUnknown:
      self.subscriptionLabel.text = @"Loading subscription status.";
      break;
  }
}

@end
