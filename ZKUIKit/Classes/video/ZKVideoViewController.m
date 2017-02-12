//
//  ZKViewController.m
//  ServerInApp
//
//  Created by wansong on 2/5/17.
//  Copyright © 2017 zhike. All rights reserved.
//

#import "ZKVideoViewController.h"

@interface ZKVideoView ()
@property (assign, nonatomic) BOOL fullscreen;
@end

@interface ZKVideoViewController () <UIViewControllerTransitioningDelegate>
@property (assign, nonatomic) Float64 beginFrom;
@property (assign, nonatomic) CGRect fromRect;
@property (assign, nonatomic) BOOL customPresentAnimation;
@end

@implementation ZKVideoViewController

- (instancetype)initWithBeginTime:(Float64)beignTime fromRect:(CGRect)fromRect customPresentAnimation:(BOOL)anim {
  self = [super init];
  if (self) {
    _beginFrom = beignTime;
    _fromRect = fromRect;
    _customPresentAnimation = anim;
    [self config];
  }
  return self;
}

- (instancetype)initWithBeginTime:(Float64)beignTime fromRect:(CGRect)fromRect {
  return [self initWithBeginTime:beignTime fromRect:fromRect customPresentAnimation:YES];
}

- (void)loadView {
  self.view = [[ZKVideoView alloc] initWithFullscreenOnly:YES beginFrom:self.beginFrom];
  self.videoView.fullscreen = YES;
}

- (void)config {
  if (self.customPresentAnimation) {
    self.transitioningDelegate = self;
  }
}

- (ZKVideoView*)videoView {
  return (ZKVideoView*)self.view;
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  if ([self isBeingDismissed]) {
    if (self.onDismiss) {
      PlayerState state = self.videoView.playerState;
      Float64 currentTime = self.videoView.currentTime;
      self.videoView.playerState = PlayerStatePaused;
      self.onDismiss(@{
                       @"currentTime": @(currentTime),
                       @"playerState": @(state),
                       });
    }
  }
  self.videoView.playerState = PlayerStatePaused;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  if (self.videoView.fullscreen) {
    return UIStatusBarStyleLightContent;
  } else {
    if (self.parentViewController) {
      return [self.parentViewController preferredStatusBarStyle];
    } else {
      return UIStatusBarStyleDefault;
    }
  }
}

- (BOOL)prefersStatusBarHidden {
  return self.videoView.fullscreen && self.videoView.titleBar.hidden;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
  if (self.videoView.fullscreen) {
    return UIInterfaceOrientationLandscapeRight;
  } else {
    return [super preferredInterfaceOrientationForPresentation];
  }
}

- (BOOL)shouldAutorotate {
  return NO;
}
@end
