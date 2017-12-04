//
//  UIImage+ZKImageUtility.h
//  SmartStudy
//
//  Created by wansong on 15/10/30.
//  Copyright © 2015年 Innobuddy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef void (^DrawingBlock)(CGSize size);

@interface UIImage (ZKImageUtility)
+ (nullable UIImage *)imageTakenFromView:(nonnull UIView *)view;
+ (nonnull UIImage *)inverseColor:(nonnull UIImage *)image;
+ (nonnull UIImage*)imageWithSize:(CGSize)size drawingBlock:(nonnull DrawingBlock)drawingBlock;
- (nonnull UIImage*)resize:(CGSize)size;
@end
