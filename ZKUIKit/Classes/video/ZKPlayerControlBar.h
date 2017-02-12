//
//  ZKPlayerControlBar.h
//  ieltsmobile
//
//  Created by wansong on 16/6/5.
//  Copyright © 2016年 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZKVideoProgressView.h"

typedef void (^bool_callback_t)(BOOL);
typedef void (^opaque_callback_t)(id sender);

@interface ZKPlayerControlBar : UIView

- (instancetype)initWithFrame:(CGRect)frame fullscreenMode:(BOOL)fullscreen;

@property (readonly, nonatomic) ZKVideoProgressView *progressView;

@property (assign, nonatomic) NSUInteger timePlayed;
@property (assign, nonatomic) NSUInteger timeTotal;

//bool means is playing
@property (copy, nonatomic) bool_callback_t playButtonAction;
@property (copy, nonatomic) opaque_callback_t rateButtonAction;
@property (copy, nonatomic) dispatch_block_t toggleFullscreenButtonAction;
@property (copy, nonatomic) opaque_callback_t customButtonAction;

- (void)syncUIWithPlayerState:(BOOL)isplaying;

- (float)currentRate;

@end
