//
//  SSAAppDelegate.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/1/22.
//

#import "SSAAppDelegate.h"

// services
#import "SSASuperwallService.h"

@interface SSAAppDelegate ()

@end

@implementation SSAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    // Initialize the Superwall service.
    [[SSASuperwallService sharedService] initialize];
    
    return YES;
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

@end
