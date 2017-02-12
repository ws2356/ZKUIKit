//
//  UIImage+ZKImageUtility.m
//  SmartStudy
//
//  Created by wansong on 15/10/30.
//  Copyright © 2015年 Innobuddy Inc. All rights reserved.
//

#import "UIImage+ZKImageUtility.h"

@implementation UIImage (ZKImageUtility)

+ (UIImage *)imageTakenFromView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage *)inverseColor:(UIImage *)image {
  CIImage *coreImage = [CIImage imageWithCGImage:image.CGImage];
  CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
  [filter setValue:coreImage forKey:kCIInputImageKey];
  CIImage *result = [filter valueForKey:kCIOutputImageKey];
  return [UIImage imageWithCIImage:result scale:image.scale orientation:image.imageOrientation];
}

+ (UIImage*)imageWithSize:(CGSize)size drawingBlock:(DrawingBlock)drawingBlock {
  UIGraphicsBeginImageContext(size);
  NSAssert(drawingBlock, @"");
  drawingBlock(size);
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

- (UIImage*)resize:(CGSize)size {
  UIGraphicsBeginImageContext(size);
  [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}
@end
