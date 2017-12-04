//
//  ZKPlayerTitleBar.h
//  ieltsmobile
//
//  Created by wansong on 16/6/5.
//  Copyright © 2016年 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ZKPlayerTitleBar : UIView

- (nonnull instancetype)initWithFrame:(CGRect)frame topReserve:(CGFloat)topReserve;

@property (copy, nonatomic) NSString * _Nullable title;
@property (copy, nonatomic) dispatch_block_t _Nullable backButtonAtion;

@end
