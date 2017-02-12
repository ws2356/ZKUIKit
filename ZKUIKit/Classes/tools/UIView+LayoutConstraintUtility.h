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

- (NSArray<NSLayoutConstraint*>*)constraintsWithSuperview;
- (NSArray<NSLayoutConstraint*>*)constraintsSelf;
- (NSArray<NSLayoutConstraint*>*)constraintsWithChildren;

@end
