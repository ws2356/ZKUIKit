//
//  ZKVideoView.h
//  VideoPlayerSample
//
//  Created by wansong.mbp.work on 8/14/16.
//  Copyright © 2016 IGN. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZKPlayerTitleBar.h"

typedef NS_ENUM(NSUInteger, PlayerState) {
  PlayerStateNull,
  PlayerStateLoading,
  PlayerStatePlaying,
  PlayerStatePaused,
  PlayerStateError,
  PlayerStateComplete,
};

typedef void (^player_event_callback_t) (NSDictionary*event);


@interface ZKVideoView : UIView

- (instancetype)initWithFullscreenOnly:(BOOL)fullscreenOnly;
- (instancetype)initWithFullscreenOnly:(BOOL)fullscreenOnly beginFrom:(Float64)beginFrom;

@property (copy, nonatomic) NSString *source;

@property (assign, nonatomic) PlayerState playerState;

@property (strong, nonatomic) NSString *videoTitle;

@property (copy, nonatomic) player_event_callback_t playerEventCallback;

@property (readonly, nonatomic) BOOL fullscreen;

@property (weak, nonatomic) UIViewController *containerVC;

@property (readonly, nonatomic) ZKPlayerTitleBar *titleBar;
@property (readonly, nonatomic) Float64 currentTime;

- (void)stop;
@end
