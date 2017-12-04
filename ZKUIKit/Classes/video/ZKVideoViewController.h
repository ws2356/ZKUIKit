//
//  ZKViewController.h
//  ServerInApp
//
//  Created by wansong on 2/5/17.
//  Copyright © 2017 zhike. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZKVideoView.h"

// require fullscreen
// require present, not push

// currentTime - required
//
typedef void (^ZKVideoViewControllerDismissAction)(NSDictionary *  _Nonnull playbackInfo);

@interface ZKVideoViewController : UIViewController

- (nonnull instancetype)initWithBeginTime:(Float64)beignTime fromRect:(CGRect)fromRect;

- (nonnull instancetype)initWithBeginTime:(Float64)beignTime fromRect:(CGRect)fromRect customPresentAnimation:(BOOL)anim;

@property (readonly, nonatomic) ZKVideoView * _Nonnull videoView;

@property (copy, nonatomic) ZKVideoViewControllerDismissAction _Nullable onDismiss;

@end
