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
+ (UIImage *)imageTakenFromView:(UIView *)view;
+ (UIImage *)inverseColor:(UIImage *)image;
+ (UIImage*)imageWithSize:(CGSize)size drawingBlock:(DrawingBlock)drawingBlock;
- (UIImage*)resize:(CGSize)size;
@end
