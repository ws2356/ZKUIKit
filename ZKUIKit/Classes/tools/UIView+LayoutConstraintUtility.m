//
//  UIView+LayoutConstraintUtility.m
//  ieltsmobile
//
//  Created by wansong on 6/8/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "UIView+LayoutConstraintUtility.h"

typedef NS_ENUM(NSInteger, ConstraintType) {
  ConstraintTypeWithSuper,
  ConstraintTypeSelf,
  ConstraintTypeChildren,
};

@implementation UIView (LayoutConstraintUtility)

- (void)removeSizeConstraints {
  NSMutableArray *toRm = [NSMutableArray array];
  [self.constraints enumerateObjectsUsingBlock:^(__kindof NSLayoutConstraint * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    if (obj.secondItem == nil && (obj.firstAttribute == NSLayoutAttributeWidth || obj.firstAttribute == NSLayoutAttributeHeight)) {
      [toRm addObject:obj];
    }
  }];
  [self removeConstraints:toRm];
}

+ (ConstraintType)constraintType:(NSLayoutConstraint*)constraint forView:(UIView*)view {
  if ((constraint.firstItem == view && constraint.secondItem == view.superview)
      || (constraint.firstItem == view.superview && constraint.secondItem == view)) {
    return ConstraintTypeWithSuper;
  }else if ((constraint.firstItem==view && constraint.secondItem==nil)||
            (constraint.firstItem==nil && constraint.secondItem==view)||
            (constraint.firstItem==view && constraint.secondItem==view)) {
    return ConstraintTypeSelf;
  }else {
    return ConstraintTypeChildren;
  }
}

- (NSArray<NSLayoutConstraint*>*)constraintsWithSuperview {
  NSMutableArray<NSLayoutConstraint*> *ret = [NSMutableArray array];
  UIView *superView = self.superview;
  
  [superView.constraints enumerateObjectsUsingBlock:^(__kindof NSLayoutConstraint * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    if ((obj.firstItem == self && obj.secondItem == superView) ||
        (obj.firstItem == superView && obj.secondItem == self)) {
      [ret addObject:obj];
    }
  }];
  return ret;
}

- (NSArray<NSLayoutConstraint*>*)constraintsSelf {
  NSMutableArray<NSLayoutConstraint*> *ret = [NSMutableArray array];
  [self.constraints enumerateObjectsUsingBlock:^(__kindof NSLayoutConstraint * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    if ([[self class] constraintType:obj forView:self] == ConstraintTypeSelf) {
      [ret addObject:obj];
    }
  }];
  return ret;
}

- (NSArray<NSLayoutConstraint*>*)constraintsWithChildren {
  NSMutableArray<NSLayoutConstraint*> *ret = [NSMutableArray array];
  [self.constraints enumerateObjectsUsingBlock:^(__kindof NSLayoutConstraint * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    if ([[self class] constraintType:obj forView:self] == ConstraintTypeChildren) {
      [ret addObject:obj];
    }
  }];
  return ret;
}

@end
