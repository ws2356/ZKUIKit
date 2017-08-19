//
//  ZKUIKitResourceManager.m
//  CocoaLumberjack
//
//  Created by wansong on 19/08/2017.
//

#import "ZKUIKitResourceManager.h"

@implementation ZKUIKitResourceManager

+ (NSBundle *)resourceBundle {
  NSBundle *current = [NSBundle bundleForClass:self];
  NSBundle *bundle = [NSBundle bundleWithPath:[current pathForResource:@"ZKUIKit-Images" ofType:@"bundle"]];
  return bundle;
}

@end
