//
//  UIViewController+SSAAdditions.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/4/22.
//

#import "UIViewController+SSAAdditions.h"

@implementation UIViewController (SSAAdditions)

+ (instancetype)ssa_storyboardViewController {
  return [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:NSStringFromClass([self class])];
}

@end
