//
//  UIFont+SSAAdditions.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/1/22.
//

#import "UIFont+SSAAdditions.h"

@implementation UIFont (SSAAdditions)

+ (UIFont *)ssa_rubikWithSize:(CGFloat)size {
  return [UIFont fontWithName:@"Rubik-Regular" size:size];
}

+ (UIFont *)ssa_rubikBoldWithSize:(CGFloat)size {
  return [UIFont fontWithName:@"Rubik-Bold" size:size];
}

@end
