//
//  SSAConstants.h
//  Superwall-UIKit-ObjC
//
//  Created by Nest 22, Inc. on 11/1/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Text Styles

typedef CGFloat SSAConstantsTextStyle;

extern CGFloat const SSAConstantsTextStyleTitle1;
extern CGFloat const SSAConstantsTextStyleBody;

typedef NS_ENUM(NSInteger, SSAConstantsFontWeight) {
  SSAConstantsFontWeightRegular,
  SSAConstantsFontWeightBold
};

#pragma mark - SSAConstants

@interface SSAConstants : NSObject

@property (nonatomic, strong, class, readonly) UIColor *primaryColor;

@property (nonatomic, copy, class, readonly) NSDictionary<NSAttributedStringKey, id> *navigationBarTitleTextAttributes;

+ (UIFont *)fontWithTextStyle:(SSAConstantsTextStyle)textStyle fontWeight:(SSAConstantsFontWeight)fontWeight;

@end

NS_ASSUME_NONNULL_END
