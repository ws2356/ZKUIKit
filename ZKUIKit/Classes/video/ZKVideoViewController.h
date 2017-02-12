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
typedef void (^ZKVideoViewControllerDismissAction)(NSDictionary *playbackInfo);

@interface ZKVideoViewController : UIViewController

- (instancetype)initWithBeginTime:(Float64)beignTime fromRect:(CGRect)fromRect;

- (instancetype)initWithBeginTime:(Float64)beignTime fromRect:(CGRect)fromRect customPresentAnimation:(BOOL)anim;

@property (readonly, nonatomic) ZKVideoView *videoView;

@property (copy, nonatomic) ZKVideoViewControllerDismissAction onDismiss;

@end
