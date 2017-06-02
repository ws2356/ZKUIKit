//
//  ZKVideoView.m
//  VideoPlayerSample
//
//  Created by wansong.mbp.work on 8/14/16.
//  Copyright © 2016 IGN. All rights reserved.
//

#import "ZKVideoView.h"
#import <objc/runtime.h>

#import <AVFoundation/AVFoundation.h>
#import "Masonry.h"
#import "ZKPlayerControlBar.h"
#import "ZKPlayerTitleBar.h"
#import "UIView+LayoutConstraintUtility.h"
#import "ZKVideoViewController.h"

#define RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define RGBACOLOR(r,g,b,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]
#define HEXRGBCOLOR(h) RGBCOLOR(((h>>16)&0xFF), ((h>>8)&0xFF), (h&0xFF))
#define HEXRGBACOLOR(h,a) RGBACOLOR(((h>>16)&0xFF), ((h>>8)&0xFF), (h&0xFF), a)

static NSInteger kControlBarAutohideInterval = 5;

static void *KVO_CTX_ITEM = &KVO_CTX_ITEM;
static void *KVO_CTX_PLAYER = &KVO_CTX_PLAYER;

@interface ZKVideoView ()

@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) AVURLAsset *asset;

@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) ZKPlayerControlBar *controlBar;
@property (strong, nonatomic) ZKPlayerTitleBar *titleBar;

@property (strong, nonatomic) NSObject *timeObserver;

@property (assign, nonatomic) BOOL beginListenForItemKVO;
@property (assign, nonatomic) BOOL listeningForPlayerKVO;

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;

@property (strong, nonatomic) NSTimer *hideControlTimer;

@property (assign, nonatomic) CMTime beginSeekTime;

@property (assign, nonatomic) BOOL wasPlaying;

@property (readonly, nonatomic) BOOL fullscreenOnly;

@property (strong, nonatomic) AVAssetImageGenerator *imageGenerator;

@property (strong, nonatomic) NSArray<NSLayoutConstraint*> *savedConstraintsWithSuper;
@property (strong, nonatomic) NSArray<NSLayoutConstraint*> *savedConstraintsSelf;

@property (assign, nonatomic) BOOL fullscreen;
@property (assign, nonatomic) Float64 beginFrom;
@end

@implementation ZKVideoView {
  BOOL _fullscreenOnly;
  NSURL *_url;
  PlayerState _playerState;
}

- (instancetype)init {
  return [self initWithFullscreenOnly:NO];
}

- (instancetype)initWithFullscreenOnly:(BOOL)fullscreenOnly {
  return [self initWithFullscreenOnly:fullscreenOnly beginFrom:0];
}

- (instancetype)initWithFullscreenOnly:(BOOL)fullscreenOnly beginFrom:(Float64)beginFrom {
  CGRect screen = [UIScreen mainScreen].bounds;
  self = [super initWithFrame:CGRectMake(CGRectGetMidX(screen), CGRectGetMidY(screen), 0, 0)];
  if (self) {
    _beginFrom = beginFrom;
    NSLog(@"setting beginFrom: %lf", beginFrom);
    _fullscreenOnly = fullscreenOnly;
    [self config];
    [self installSubviews];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(enterBackground:)
     name:UIApplicationWillResignActiveNotification
     object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(willEnterForeground:)
     name:UIApplicationDidBecomeActiveNotification
     object:nil];
    self.backgroundColor = [UIColor blackColor];
  }
  NSLog(@"video(%@) is being alloc", self);
  return self;
}

- (void)enterBackground:(NSNotification*)notification {
  self.wasPlaying = [self supposedToPlay];
  if (self.wasPlaying) {
    self.playerState = PlayerStatePaused;
  }
}

- (void)willEnterForeground:(NSNotification*)notification {
  if (self.wasPlaying) {
    self.playerState = PlayerStatePlaying;
  }
}

- (void)dealloc {
  NSLog(@"video(%@) is being dealloc", self);
  
  player_event_callback_t callback = self.playerEventCallback;
  if (callback) {
    callback(@{@"name": @"quit play", @"time": @(self.controlBar.timePlayed)});
  }
  
  [self clearPlayer];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIViewController*)pairedVC {
  UIViewController *pairedVC = (UIViewController*)[self nextResponder];
  if ([pairedVC isKindOfClass:UIViewController.class] && pairedVC.view == self) {
    return pairedVC;
  } else {
    return nil;
  }
}

- (Float64)currentTime {
  if (self.player.currentItem) {
    return CMTimeGetSeconds(self.player.currentItem.currentTime);
  } else {
    return 0;
  }
}

- (BOOL)fullscreenOnly {
  return _fullscreenOnly;
}

- (BOOL)shouldForbidShowTitleBar {
  return !self.fullscreen;
}

- (void)setFullscreen:(BOOL)fullscreen {
  _fullscreen = fullscreen;
  player_event_callback_t callback = self.playerEventCallback;
  if (callback) {
    callback(@{@"name":@"screenUpdate", @"fullscreen":@(fullscreen)});
  }
  [[self pairedVC] setNeedsStatusBarAppearanceUpdate];
}

- (void)config {
  
  NSError *error = nil;
  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
  if (error) {
    NSLog(@"failed to setCategory with category: %ld, error: %@",
          (long)AVAudioSessionCategoryPlayback,
          error);
  }
  AVPlayerLayer *playerLayer = (AVPlayerLayer *)[self layer];
  playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
  
  playerLayer.backgroundColor = [UIColor blackColor].CGColor;
  self.backgroundColor = [UIColor blackColor];
}

- (void)installSubviews {
  self.titleBar = [[ZKPlayerTitleBar alloc] initWithFrame:CGRectZero topReserve:0];
  
  typeof(self) __weak weakSelf = self;
  
  self.titleBar.backButtonAtion = ^{
    [weakSelf toggleFullscreen];
  };
  
  [self startTimerToHideControl];
  
  self.controlBar = [[ZKPlayerControlBar alloc] initWithFrame:CGRectZero
                                               fullscreenMode:self.fullscreenOnly];
  
  self.controlBar.playButtonAction = ^(BOOL isPlaying) {
    if (isPlaying) {
      weakSelf.playerState = PlayerStatePlaying;
    }else {
      weakSelf.playerState = PlayerStatePaused;
    }
  };
  
  self.controlBar.rateButtonAction = ^(id reate) {
    CGFloat rate = [(NSNumber*)reate floatValue];
    weakSelf.player.rate = rate;
    
    player_event_callback_t callback = weakSelf.playerEventCallback;
    if (callback) {
      callback(@{@"name":@"rate change", @"rate":[NSString stringWithFormat:@"%.2f", rate]});
    }
  };
  
  if (self.fullscreenOnly) {
    self.controlBar.toggleFullscreenButtonAction = self.titleBar.backButtonAtion;
  }else {
    //todo: fix this
    self.controlBar.toggleFullscreenButtonAction = ^() {
      [weakSelf toggleFullscreen];
    };
  }
  
  [self addSubview:self.titleBar];
  [self addSubview:self.controlBar];
  
  [self.titleBar mas_makeConstraints:^(MASConstraintMaker *make) {
    make.leading.and.top.and.trailing.equalTo(self);
    make.height.equalTo(@64);
  }];
  [self.controlBar mas_makeConstraints:^(MASConstraintMaker *make) {
    make.leading.and.bottom.and.trailing.equalTo(self);
    make.top.greaterThanOrEqualTo(self.titleBar.mas_bottom).priorityLow();
    make.height.equalTo(@50);
  }];
  
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(tapAction:)];
  [self addGestureRecognizer:tap];
  
  UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(panGestureAction:)];
  UIPanGestureRecognizer *pan2 = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(panGestureAction:)];
  
  [self addGestureRecognizer:pan];
  [self.controlBar addGestureRecognizer:pan2];
  
  [self tapAction:nil];[self tapAction:nil];
}

- (NSString*)videoTitle {
  return self.titleBar.title;
}

- (void)setVideoTitle:(NSString*)videoTitle {
  self.titleBar.title = videoTitle;
}

- (void)toggleFullscreen {
  self.fullscreen = !self.fullscreen;
  //fixme
  self.titleBar.hidden = YES;
  self.controlBar.hidden = YES;
  typeof(self) __weak weakSelf = self;
  if (self.fullscreen) {
    UIView *window = [UIApplication sharedApplication].keyWindow;
    ZKVideoViewController *vc = [[ZKVideoViewController alloc] initWithBeginTime:self.currentTime
                                 fromRect:[self convertRect:self.bounds toView:window]];
    vc.onDismiss = ^(NSDictionary *playbackInfo){
      NSNumber *currentTime = playbackInfo[@"currentTime"];
      if (currentTime) {
        [weakSelf.player.currentItem seekToTime:CMTimeMakeWithSeconds([currentTime doubleValue], NSEC_PER_SEC)];
      }
      NSNumber *playerState = playbackInfo[@"playerState"];
      if (playbackInfo) {
        weakSelf.playerState = (PlayerState)[playerState integerValue];
      }
      weakSelf.fullscreen = NO;
    };
    vc.videoView.asset = self.asset;
    [self.containerVC presentViewController:vc animated:YES completion:nil];
    vc.videoView.playerState = self.playerState;
    self.playerState = PlayerStatePaused;
  }else {
    [[self pairedVC] dismissViewControllerAnimated:YES completion:nil];
    [self tapAction:nil];[self tapAction:nil];
  }
}

- (void)tapAction:(UITapGestureRecognizer*)tap {
  if (self.fullscreen || self.fullscreenOnly) {
    self.titleBar.hidden = !self.titleBar.hidden;
  }else {
    self.titleBar.hidden = YES;
  }
  self.controlBar.hidden = !self.controlBar.hidden;
  
  [self startTimerToHideControl];
  
  [[self pairedVC] setNeedsStatusBarAppearanceUpdate];
}

- (void)panGestureAction:(UIPanGestureRecognizer*)pan {
  if (CMTIME_IS_INDEFINITE(self.player.currentItem.duration)
      || CMTIME_IS_INDEFINITE(self.player.currentItem.currentTime)) {
    return;
  }
  
  float deltaRelative = [pan translationInView:pan.view].x / CGRectGetWidth(pan.view.bounds);
  
  if (pan.state == UIGestureRecognizerStateBegan) {
    [self showActivityIndicator];
    self.beginSeekTime = self.player.currentItem.currentTime;
    self.playerState = PlayerStatePaused;
  }else if (pan.state == UIGestureRecognizerStateChanged) {
    [self updateProgressBarUI:deltaRelative];
  }else {
    [self updateProgressBarUI:deltaRelative];
    CMTime duration = self.player.currentItem.duration;
    NSInteger durationSeconds = CMTimeGetSeconds(duration);
    NSInteger deltaSeconds = (NSInteger)(deltaRelative * CMTimeGetSeconds(duration));
    NSInteger currentSeconds = CMTimeGetSeconds(self.player.currentItem.currentTime);
    NSInteger currentTimeUpdated = MIN(currentSeconds+deltaSeconds, durationSeconds);
    NSLog(@"begin seek to: %lu, duration: %lu", currentTimeUpdated, durationSeconds);
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem seekToTime:CMTimeMakeWithSeconds(currentTimeUpdated, NSEC_PER_SEC)
                      completionHandler:^(BOOL finished) {
      dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger time = (NSUInteger)CMTimeGetSeconds(self.beginSeekTime);
        NSUInteger end = (NSUInteger)CMTimeGetSeconds(self.player.currentItem.currentTime);
        
        if (finished) {
          NSLog(@"did end seek beginTime: %lu, currentTime: %lu",time, end);
          [self hideActivityIndicator];
        }
        self.playerState = PlayerStatePlaying;
        
        player_event_callback_t callback = self.playerEventCallback;
        if (callback) {
          callback(@{@"name":@"end seek", @"time":@(time), @"end":@(end)});
        }
      });
    }];
    [pan setTranslation:CGPointZero inView:pan.view];
  }
}

- (void)seekToSeconds:(Float64)time completion:(void(^)(BOOL finished))completion {
  NSLog(@"seeking to time: %lf", time);
  [self.player.currentItem
   seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)
   completionHandler:^(BOOL finished){
     NSLog(@"did seek to time: %lf", time);
    if (completion) {
      completion(finished);
    }
  }];
}

- (void)updateProgressBarUI:(float)deltaRelative {
  CMTime dur = self.player.currentItem.duration;
  NSAssert(!CMTIME_IS_INDEFINITE(dur), @"");
  Float64 durSeconds = CMTimeGetSeconds(dur);
  Float64 deltaSeconds = deltaRelative * durSeconds;
  Float64 current = CMTimeGetSeconds(self.beginSeekTime);
  Float64 progress = MIN(current+deltaSeconds, durSeconds) / durSeconds;
  self.controlBar.progressView.progress = progress;
}

- (void)startTimerToHideControl {
  if (self.hideControlTimer && self.hideControlTimer.valid) {
    [self.hideControlTimer invalidate];
  }
  self.hideControlTimer = [NSTimer
                           scheduledTimerWithTimeInterval:kControlBarAutohideInterval
                           target:self
                           selector:@selector(delayedHideControlBar:)
                           userInfo:nil
                           repeats:NO];
}

- (void)delayedHideControlBar:(NSTimer*)timer {
  if (!self.controlBar.hidden) {
    [self tapAction:nil];
  }
  [timer invalidate];
}

+(Class)layerClass {
  return [AVPlayerLayer class];
}

-(AVPlayer *)player {
  return [(AVPlayerLayer *)[self layer]player];
}

-(void)setPlayer:(AVPlayer *)player {
  return [(AVPlayerLayer *)[self layer] setPlayer:player];
}

- (void)setSource:(NSString *)source {
  _source = [source copy];
  if ([[NSFileManager defaultManager] fileExistsAtPath:source]) {
    self.url = [NSURL fileURLWithPath:source isDirectory:NO];
  }else {
    self.url = [NSURL URLWithString:source];
  }
}

- (NSURL*)url {
  return _url;
}

#pragma mark -- view
- (void)showActivityIndicator {
  if (!self.activityIndicator) {
    UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] init];
    activity.hidesWhenStopped = YES;
    self.activityIndicator = activity;
    [self addSubview:activity];
    [activity mas_makeConstraints:^(MASConstraintMaker *make) {
      make.centerX.equalTo(self.mas_centerX);
      make.centerY.equalTo(self.mas_centerY);
      make.height.equalTo(@100);
      make.width.equalTo(@100);
    }];
  }
  
  [self bringSubviewToFront:self.activityIndicator];
  [self.activityIndicator startAnimating];
}

- (void)hideActivityIndicator {
  [self.activityIndicator stopAnimating];
}

#pragma mark -- playback management

- (void)clearPlayer {
  [self clearPlayerItem];
  
  if (self.timeObserver) {
    [self removeTimeObserver];
  }
  if (self.listeningForPlayerKVO) {
    [self detachKVOForPlayer];
  }
  
  self.player = nil;
}

- (void)clearPlayerItem {
  if (self.beginListenForItemKVO) {
    [self detachKVOForItem:self.player.currentItem];
  }
  [self clearEndNotificationForPlayerItem:self.player.currentItem];
}

- (void)setUrl:(NSURL *)url {
  if (_url) {
    [self stop];
  }
  _url = url;
  
  if ([self supposedToPlay] || self.fullscreenOnly) {
    self.playerState = PlayerStatePlaying;
  }
  
}

- (NSURL*)convertSuffixToMp4:(NSURL*)url {
  NSString *urlString = [url absoluteString];
  NSString *tillDirectory = [urlString stringByDeletingLastPathComponent];
  NSMutableArray *nameAndSuffix =
  [[[urlString lastPathComponent] componentsSeparatedByString:@"."] mutableCopy];
  if (!nameAndSuffix.count) {
    return nil;
  }else {
    NSLog(@"replacing suffix: %@ with %@", nameAndSuffix.lastObject, @"mp4");
    NSLog(@"before convert: %@", url.absoluteString);
    
    [nameAndSuffix removeLastObject];
    [nameAndSuffix addObject:@"mp4"];
    NSString *nameAndSuffixStr = [nameAndSuffix componentsJoinedByString:@"."];
    NSString *newUrlStr = [tillDirectory stringByAppendingPathComponent:nameAndSuffixStr];
    
    NSLog(@"after convert: %@", newUrlStr);
    return [NSURL URLWithString:newUrlStr];
  }
}

- (void)beginGenerateThumbail:(NSURL*)url {
  NSURL *mp4Url = [self convertSuffixToMp4:url];
  if (!mp4Url) {
    NSLog(@"failed to convert url: %@", url);
  }else {
    self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:[AVURLAsset assetWithURL:mp4Url]];
    NSLog(@"begin getting thumbnal from video");
    [self.imageGenerator
     generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:kCMTimeZero]]
     completionHandler:
     ^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
       UIImage *uiImage = [UIImage imageWithCGImage:image];
       NSData *imageData = UIImagePNGRepresentation(uiImage);
       if (imageData) {
         NSString *image64 =
         [imageData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
         if (image64) {
           NSLog(@"did get thumbnail fro video");
           return;
         }
       }
       NSLog(@"try but failed to get thumbnail from video");
     }];
  }
}

- (void)resume:(dispatch_block_t)completionHandler {
  int32_t comp = CMTimeCompare(self.player.currentItem.currentTime, self.player.currentItem.duration);
  if (comp >= 0 && CMTimeGetSeconds(self.player.currentItem.duration) > 0) {
    [self.player.currentItem seekToTime:CMTimeMake(0, 1)
                      completionHandler:^(BOOL finished) {
                        if (finished) {
                          [self resume:completionHandler];
                        }
                      }];
  }else {
    [self.controlBar syncUIWithPlayerState:YES];
    if (self.player) {
      _playerState = PlayerStateLoading;
      self.player.rate = [self.controlBar currentRate];
      player_event_callback_t callback = self.playerEventCallback;
      if (callback) {
        callback(@{@"name": @"resume play", @"time": @(self.controlBar.timePlayed)});
      }
    }else {
      _playerState = PlayerStatePlaying;
      [self start];
    }
    
    if (completionHandler) {
      completionHandler();
    }
  }
}

- (void)pause {
  [self.player pause];
  [self.controlBar syncUIWithPlayerState:NO];
  
  player_event_callback_t callback = self.playerEventCallback;
  if (callback) {
    callback(@{@"name": @"pause play", @"time": @(self.controlBar.timePlayed)});
  }
}

- (void)stop {
  self.playerState = PlayerStatePaused;
  [self clearPlayer];
}

- (void)start {
  [self startUsingAsset:NO];
}

- (void)startUsingAsset:(BOOL)usingAsset {
  if (!_url) {
    return;
  }
  
  player_event_callback_t callback = self.playerEventCallback;
  if (callback) {
    callback(@{@"name": @"start play"});
  }
  
  self.playerState = PlayerStateLoading;
  [self.controlBar syncUIWithPlayerState:YES];
  
  [self showActivityIndicator];
  
  AVURLAsset *asset = usingAsset ? self.asset : [AVURLAsset assetWithURL:self.url];
  _asset = asset;
  AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:self.asset];
  if (!self.player) {
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    NSAssert(self.player.currentItem, @"");
    [self configurePlayer];
    [self configurePlayerItem:self.player.currentItem];
  }else {
    if (playerItem) {
      [self replaceCurrentItemWithItem:playerItem];
    }else {
      NSAssert(NO, @"failed to get a AVPlayerItem for video: %@", self.url);
    }
  }
  
  [self.player play];
  
  if (self.fullscreenOnly && !self.fullscreen) {
    dispatch_after(
                   dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     [self toggleFullscreen];
                   });
  }
}

- (void)setAsset:(AVURLAsset *)asset {
  if (_asset != asset) {
    _url = asset.URL;
    _asset = asset;
    [self startUsingAsset:YES];
  }
}

- (void)configurePlayer {
  self.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
  [self attachKVOForPlayer];
  [self addTimeObserver];
}

- (void)configurePlayerItem:(AVPlayerItem*)playerItem {
  [self addEndNotificationForPlayerItem:playerItem];
  [self attachKVOForItem:playerItem];
}

- (void)replaceCurrentItemWithItem:(AVPlayerItem*)playerItem {
  [self clearPlayerItem];
  [self.player replaceCurrentItemWithPlayerItem:playerItem];
  [self configurePlayerItem:playerItem];
}

- (void)attachKVOForPlayer {
  self.listeningForPlayerKVO = YES;
  [self.player addObserver:self
               forKeyPath:@"status"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:KVO_CTX_PLAYER];
}

- (void)detachKVOForPlayer {
  self.listeningForPlayerKVO = NO;
  [self.player removeObserver:self
                   forKeyPath:@"status"
                      context:KVO_CTX_PLAYER];
}

- (void)attachKVOForItem:(AVPlayerItem*)playerItem {
  self.beginListenForItemKVO = YES;
  //accumulating property can be assumed to have a initial value of 0
  [playerItem addObserver:self
               forKeyPath:@"loadedTimeRanges"
                  options:NSKeyValueObservingOptionNew
                  context:KVO_CTX_ITEM];
  
  [playerItem addObserver:self
               forKeyPath:@"status"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:KVO_CTX_ITEM];
  
  [playerItem addObserver:self
               forKeyPath:@"duration"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:KVO_CTX_ITEM];
}

- (void)detachKVOForItem:(AVPlayerItem*)playerItem {
  self.beginListenForItemKVO = NO;
  [playerItem removeObserver:self
                  forKeyPath:@"loadedTimeRanges"
                     context:KVO_CTX_ITEM];
  [playerItem removeObserver:self
                  forKeyPath:@"status"
                     context:KVO_CTX_ITEM];
  [playerItem removeObserver:self
                  forKeyPath:@"duration"
                     context:KVO_CTX_ITEM];
}

- (void)addEndNotificationForPlayerItem:(AVPlayerItem*)item {
  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(playerItemDidPlayToEnd:)
   name:AVPlayerItemDidPlayToEndTimeNotification
   object:item];
}

- (void)clearEndNotificationForPlayerItem:(AVPlayerItem*)item {
  [[NSNotificationCenter defaultCenter]
   removeObserver:self
   name:AVPlayerItemDidPlayToEndTimeNotification
   object:item];
}

//we should keep ui in sync
- (void)playerItemDidPlayToEnd:(NSNotification*)notification {
  [self.controlBar syncUIWithPlayerState:NO];
  
  player_event_callback_t callback = self.playerEventCallback;
  if (callback) {
    callback(@{@"name": @"finish play", @"time": @(self.controlBar.timePlayed)});
  }
  
}

- (void)addTimeObserver {
  NSAssert(self.player, @"");
  if (!self.timeObserver) {
    __weak typeof(self)weakSelf = self;
    self.timeObserver =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
      if (CMTIME_IS_INDEFINITE(time)) {
        time = kCMTimeZero;
      }
      [weakSelf updateCurrentTime:(NSUInteger)CMTimeGetSeconds(time)];
    }];
  }else {
    NSAssert(NO, @"time only one time observer should be running at a time");
  }
}

- (void)updateCurrentTime:(NSUInteger)time {
  self.controlBar.timePlayed = time;
  NSUInteger dur = CMTimeGetSeconds(self.player.currentItem.duration);
  self.controlBar.progressView.progress = dur > 0 ? 1.0 * time / dur*1.0 : 0;
}

-(void)removeTimeObserver {
  [self.player removeTimeObserver:self.timeObserver];
  self.timeObserver = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
  
  if (context == KVO_CTX_PLAYER) {
    NSAssert(object == self.player, @"");
    
    if ([keyPath isEqualToString:@"status"]) {
      NSNumber *statueVal = change[NSKeyValueChangeNewKey];
      if (statueVal) {
        switch (statueVal.integerValue) {
          case AVPlayerStatusFailed:
            [self handlePlayerError:YES];
            [self hideActivityIndicator];
            break;
          case AVPlayerStatusReadyToPlay:
            if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
              [self playerReady];
            }else {
              [self showActivityIndicator];
            }
            break;
          case AVPlayerStatusUnknown:
            [self showActivityIndicator];
            break;
          default:
            NSAssert(NO, @"");
            break;
        }
      }
    }
  }else if (context == KVO_CTX_ITEM) {
    NSAssert(object == self.player.currentItem, @"");
    
    if ([keyPath isEqualToString:@"status"]) {
      NSNumber *statueVal = change[NSKeyValueChangeNewKey];
      if (statueVal) {
        switch (statueVal.integerValue) {
          case AVPlayerItemStatusReadyToPlay:
            if (self.player.status == AVPlayerStatusReadyToPlay) {
              [self playerReady];
            }else {
              [self showActivityIndicator];
            }
            break;
          case AVPlayerItemStatusFailed:
            [self handlePlayerError:NO];
            [self hideActivityIndicator];
            break;
          case AVPlayerStatusUnknown:
            [self showActivityIndicator];
            break;
          default:
            NSAssert(NO, @"");
            break;
        }
      }
    }else if ([keyPath isEqualToString:@"duration"]) {
      [self updateItemDuration];
    }else {
      [self handleLoadedTimeRangeUpdate];
    }
  }else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

- (void)playerReady {
  [self hideActivityIndicator];
  if (self.playerState == PlayerStateLoading) {
    self.playerState = PlayerStatePlaying;
  }
  if (self.beginFrom > 0) {
    NSLog(@"seeking to time: %lf", self.beginFrom);
    [self seekToSeconds:self.beginFrom completion:nil];
    self.beginFrom = 0;
  }
}

- (void)updateItemDuration {
  AVPlayerItem *item = self.player.currentItem;
  CMTime duration = CMTIME_IS_INDEFINITE(item.duration) ? kCMTimeZero : item.duration;
  self.controlBar.timeTotal = CMTimeGetSeconds(duration);
}

- (void)handlePlayerError:(BOOL)playerOrItem {
  NSError *error = playerOrItem ? self.player.error : self.player.currentItem.error;
  NSLog(@"%@ error: %@", playerOrItem ? @"player" : @"player item", error);
  
  [self clearPlayer];
  [self hideActivityIndicator];
}

- (void)handleLoadedTimeRangeUpdate {
  NSUInteger dur = CMTimeGetSeconds(self.player.currentItem.duration);
  [self.controlBar.progressView updateLoadedRanges:self.player.currentItem.loadedTimeRanges duration:dur];
}

#pragma mark -- js interface
- (BOOL)supposedToPlay {
  return (
          self.playerState == PlayerStatePlaying ||
          self.playerState == PlayerStateLoading
  );
}

- (void)setPlayerState:(PlayerState)playerState {
  switch (playerState) {
    case PlayerStatePlaying:
      if (_playerState == PlayerStateError) {
        _playerState = playerState;
        [self start];
      }else {
        _playerState = playerState;
        [self resume:nil];
      }
      break;
    case PlayerStatePaused:
      [self pause];
      break;
    case PlayerStateLoading:
      break;
    case PlayerStateComplete:
      break;
    case PlayerStateError:
      break;
    default:
      NSAssert(NO, @"");
      break;
  }
  _playerState = playerState;
}


@end
