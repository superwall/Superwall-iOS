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
  [self updateForEntitlements];

  // Listen for changes to the subscription state.
  __weak typeof(self) weakSelf = self;
  [[NSNotificationCenter defaultCenter] addObserverForName:SSAAppDelegateDidUpdateEntitlements object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
    [weakSelf updateForEntitlements];
  }];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
}

#pragma mark - Actions

- (IBAction)registerPlacement:(id)sender {
  SWKPaywallPresentationHandler *handler = [[SWKPaywallPresentationHandler alloc] init];

  [handler onDismiss:^(SWKPaywallInfo * _Nonnull paywallInfo, enum SWKPaywallResult paywallResult, SWKStoreProduct * _Nullable product) {
    NSLog(@"The paywall dismissed. PaywallInfo: %@, PaywallResult: %ld, product %@", paywallInfo, (long)paywallResult, product);
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
      case SWKPaywallSkippedReasonNoAudienceMatch:
        NSLog(@"Paywall not shown because user doesn't match any audience.");
        break;
      case SWKPaywallSkippedReasonPlacementNotFound:
        NSLog(@"Paywall not shown because this placement isn't part of a campaign.");
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

- (void)updateForEntitlements {
  bool didSetActiveEntitlements = Superwall.sharedInstance.entitlements.didSetActiveEntitlements;

  if (didSetActiveEntitlements) {
    if (Superwall.sharedInstance.entitlements.active.count == 0) {
      self.subscriptionLabel.text = @"You do not have any active entitlements so the paywall will always show when clicking the button.";
    } else {
      self.subscriptionLabel.text = @"You currently have an active entitlement. The audience filter is configured to only show a paywall if there are no entitlements so the paywall will never show. For the purposes of this app, delete and reinstall the app to clear entitlements.";
    }
  } else {
    self.subscriptionLabel.text = @"Loading entitlements.";
  }
}

@end
