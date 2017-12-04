//
//  UIView+LayoutConstraintUtility.h
//  ieltsmobile
//
//  Created by wansong on 6/8/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (LayoutConstraintUtility)

- (void)removeSizeConstraints;

- (nonnull NSArray<NSLayoutConstraint*>*)constraintsWithSuperview;
- (nonnull NSArray<NSLayoutConstraint*>*)constraintsSelf;
- (nonnull NSArray<NSLayoutConstraint*>*)constraintsWithChildren;

@end
