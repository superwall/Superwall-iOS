//
//  main.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/1/22.
//

#import <UIKit/UIKit.h>
#import "SSAAppDelegate.h"

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([SSAAppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
