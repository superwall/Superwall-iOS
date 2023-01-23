//
//  SSAConstants.m
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/1/22.
//

#import "SSAConstants.h"

// categories
#import "UIColor+SSAAdditions.h"
#import "UIFont+SSAAdditions.h"

CGFloat const SSAConstantsTextStyleTitle1 = 28.0;
CGFloat const SSAConstantsTextStyleBody = 17.0;

@implementation SSAConstants

+ (UIColor *)primaryColor {
  return [UIColor ssa_tealColor];
}

+ (NSDictionary<NSAttributedStringKey,id> *)navigationBarTitleTextAttributes {
  return @{
    NSForegroundColorAttributeName: [UIColor whiteColor],
    NSFontAttributeName: [SSAConstants fontWithTextStyle:SSAConstantsTextStyleBody fontWeight:SSAConstantsFontWeightRegular]
  };
}

+ (UIFont *)fontWithTextStyle:(SSAConstantsTextStyle)textStyle fontWeight:(SSAConstantsFontWeight)fontWeight {
  switch (fontWeight) {
    case SSAConstantsFontWeightRegular:
      return [UIFont ssa_rubikWithSize:textStyle];
      break;
    case SSAConstantsFontWeightBold:
      return [UIFont ssa_rubikBoldWithSize:textStyle];
      break;
    default:
      return [UIFont ssa_rubikWithSize:textStyle];
      break;
  }
}

@end
