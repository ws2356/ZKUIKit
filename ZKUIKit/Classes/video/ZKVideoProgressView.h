//
//  ZKVideoProgressView.h
//  ieltsmobile
//
//  Created by wansong on 16/6/6.
//  Copyright © 2016年 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ZKVideoProgressView : UIView

@property (assign, nonatomic) CGFloat progress;

- (void)updateLoadedRanges:(nonnull NSArray<NSValue*> *)loadedRanges
                  duration:(float)duration;

@property (strong, nonatomic) NSArray<NSNumber*> * _Nullable dots;

@end
