//
//  ViewController.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/1/22.
//

#import "SSAWelcomeViewController.h"

// categories
#import "UIViewController+SSAAdditions.h"

// constants
#import "SSAConstants.h"

// services
#import "SSASuperwallService.h"

// view controllers
#import "SSATrackEventViewController.h"

@interface SSAWelcomeViewController () <UITextFieldDelegate>

@property (nonatomic, strong) IBOutlet UIView *textFieldBackgroundView;
@property (nonatomic, strong) IBOutlet UITextField *textField;

@end

@implementation SSAWelcomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([SSASuperwallService sharedService].isLoggedIn) {
        [self presentTrackEventViewController];
    }
    
    // Configure view.
    self.textFieldBackgroundView.layer.cornerRadius = CGRectGetHeight(self.textFieldBackgroundView.bounds) / 2.0;
    
    // Configure navigation controller.
    UINavigationBar.appearance.titleTextAttributes = SSAConstants.navigationBarTitleTextAttributes;
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

#pragma mark - Actions

- (IBAction)login:(id)sender {
    // Store the user's name.
    NSString *name = self.textField.text;
    [SSASuperwallService sharedService].name = name;
    
    // Perform a demo login to the account.
    __weak typeof(self) weakSelf = self;
    [[SSASuperwallService sharedService] logInWithCompletion:^{
        [weakSelf presentTrackEventViewController];
    }];
}

#pragma mark - Private

- (void)presentTrackEventViewController {
    UIViewController *viewController = [SSATrackEventViewController ssa_storyboardViewController];
    [self.navigationController pushViewController:viewController animated:YES];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
