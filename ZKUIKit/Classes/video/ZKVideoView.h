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

typedef void (^player_event_callback_t) (NSDictionary * _Nullable event);


@interface ZKVideoView : UIView

- (nonnull instancetype)initWithFullscreenOnly:(BOOL)fullscreenOnly;
- (nonnull instancetype)initWithFullscreenOnly:(BOOL)fullscreenOnly beginFrom:(Float64)beginFrom;

@property (copy, nonatomic) NSString * _Nullable source;

@property (assign, nonatomic) PlayerState playerState;

@property (strong, nonatomic) NSString * _Nullable videoTitle;

@property (copy, nonatomic) player_event_callback_t _Nullable playerEventCallback;

@property (readonly, nonatomic) BOOL fullscreen;

@property (weak, nonatomic) UIViewController * _Nullable containerVC;

@property (readonly, nonatomic) ZKPlayerTitleBar * _Nullable titleBar;
@property (readonly, nonatomic) Float64 currentTime;

- (void)stop;
@end
