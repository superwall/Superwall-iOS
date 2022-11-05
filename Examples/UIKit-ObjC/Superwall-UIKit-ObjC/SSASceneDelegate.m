//
//  SSASceneDelegate.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/1/22.
//

#import "SSASceneDelegate.h"

// services
#import "SSASuperwallService.h"

@interface SSASceneDelegate ()

@end

@implementation SSASceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    [self handleURLContexts:connectionOptions.URLContexts];
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    [self handleURLContexts:URLContexts];
}

#pragma mark - Deep linking

- (void)handleURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    [URLContexts enumerateObjectsUsingBlock:^(UIOpenURLContext * _Nonnull context, BOOL * _Nonnull stop) {
        [[SSASuperwallService sharedService] handleDeepLinkWithURL:context.URL];
    }];
}

@end
