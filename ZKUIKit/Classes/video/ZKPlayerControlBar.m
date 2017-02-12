//
//  ZKPlayerControlBar.m
//  ieltsmobile
//
//  Created by wansong on 16/6/5.
//  Copyright © 2016年 Facebook. All rights reserved.
//

#import "ZKPlayerControlBar.h"
#import "Masonry.h"
#import "ZKVideoProgressView.h"
#import "UIImage+ZKImageUtility.h"

@interface ZKPlayerControlBar ()

@property (strong, nonatomic) UILabel *lbProgressDuration;

@property (strong, nonatomic) UIButton *btPlay;

@property (strong, nonatomic) ZKVideoProgressView *progressView;

@property (assign, nonatomic) NSInteger whichRate;

@end

@implementation ZKPlayerControlBar

- (instancetype)initWithFrame:(CGRect)frame fullscreenMode:(BOOL)fullscreen {
  self = [super initWithFrame:frame];
  if (self) {
    self.whichRate = [[[self class] supportedRates] indexOfObject:@1];
    NSAssert(self.whichRate != NSNotFound, @"");
    [self setupSubviewsFullscreen:fullscreen];
  }
  return self;
}

- (void)setupSubviewsFullscreen:(BOOL)fullscreen {
  self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
  
  _progressView = [ZKVideoProgressView new];
  
  NSBundle *bundle = [NSBundle bundleForClass:self.class];
  
  UIButton *btPlay = [UIButton new];
  self.btPlay = btPlay;
  [btPlay addTarget:self
             action:@selector(togglePlayAction:)
   forControlEvents:UIControlEventTouchUpInside];
  UIImage *icPause = [UIImage imageNamed:@"ic-pause" inBundle:bundle compatibleWithTraitCollection:nil];
  UIImage *icPlay = [UIImage imageNamed:@"ic-play" inBundle:bundle compatibleWithTraitCollection:nil];
  [btPlay setImage:icPause forState:UIControlStateNormal];
  [btPlay setImage:icPlay forState:UIControlStateSelected];
  
  UIButton *btRate = [UIButton new];
  UIFont *courierFt = [UIFont fontWithName:@"Courier" size:[UIFont systemFontSize]];
  btRate.titleLabel.font = courierFt;
  btRate.titleLabel.textAlignment = NSTextAlignmentCenter;
  [btRate addTarget:self
             action:@selector(rateAction:)
   forControlEvents:UIControlEventTouchUpInside];
  btRate.layer.cornerRadius = 2;
  btRate.layer.borderWidth = 1;
  btRate.layer.borderColor = [UIColor whiteColor].CGColor;
  btRate.contentEdgeInsets = UIEdgeInsetsMake(2, 5, 2, 5);
  
  self.lbProgressDuration = [UILabel new];
  self.lbProgressDuration.textColor = [UIColor whiteColor];
  self.lbProgressDuration.font = [UIFont fontWithName:@"Courier" size:14];
  [self renderRate:btRate];
  
  [self addSubview:self.progressView];
  [self addSubview:btPlay];
  [self addSubview:self.lbProgressDuration];
  [self addSubview:btRate];
  
  UIButton *btScreen = !fullscreen ? [UIButton new] : nil;;
  [btScreen addTarget:self
             action:@selector(fullscreenAction:)
   forControlEvents:UIControlEventTouchUpInside];
  [btScreen setImage:[UIImage inverseColor:[UIImage imageNamed:@"ic-fullscreen-black" inBundle:bundle compatibleWithTraitCollection:nil]] forState:UIControlStateNormal];
  
  [self addSubview:btScreen];
  
  const CGFloat left = 10;
  const CGFloat right = 10;
  const CGFloat spacingH = 10;
  const CGFloat bottom = 10;
  
  [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.leading.and.top.trailing.equalTo(self);
  }];
  [btPlay mas_makeConstraints:^(MASConstraintMaker *make) {
    make.leading.equalTo(self.mas_leading).offset(left);
    make.bottom.equalTo(self.mas_bottom).offset(-bottom);
  }];
  [self.lbProgressDuration mas_makeConstraints:^(MASConstraintMaker *make) {
    make.leading.equalTo(btPlay.mas_trailing).offset(spacingH);
    make.bottom.equalTo(btPlay.mas_bottom);
  }];
  
  [btScreen mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(btPlay.mas_centerY);
    make.trailing.equalTo(self.mas_trailing).offset(-right);
  }];
  
  if (!fullscreen) {
    [btRate mas_makeConstraints:^(MASConstraintMaker *make) {
      make.centerY.equalTo(btPlay.mas_centerY);
      make.trailing.equalTo(btScreen.mas_leading).offset(-spacingH);
      make.leading.greaterThanOrEqualTo(self.lbProgressDuration.mas_trailing).priorityLow();
    }];
  }else {
    [btRate mas_makeConstraints:^(MASConstraintMaker *make) {
      make.centerY.equalTo(btPlay.mas_centerY);
      make.trailing.equalTo(self.mas_trailing).offset(-right);
      make.leading.greaterThanOrEqualTo(self.lbProgressDuration.mas_trailing).priorityLow();
    }];
  }
  
}

- (void)renderRate:(UIButton*)rateButton {
  NSString *rateString = [NSString stringWithFormat:@"%.2f", [self currentRate]];
  [rateButton setTitle:rateString forState:UIControlStateNormal];
}

- (float)currentRate {
  return [[[self class] supportedRates][self.whichRate] floatValue];
}

- (void)togglePlayAction:(UIButton*)sender {
  sender.selected = !sender.selected;
  self.playButtonAction(!sender.selected);
}

- (void)fullscreenAction:(UIButton*)sender {
  self.toggleFullscreenButtonAction();
}

- (void)rateAction:(UIButton*)sender {
  NSArray *rates = [[self class] supportedRates];
  self.whichRate = (self.whichRate + 1) % rates.count;
  [self renderRate:sender];
  self.rateButtonAction(rates[self.whichRate]);
}

+ (NSArray<NSNumber*> *)supportedRates {
  static NSArray<NSNumber*> *ret = nil;
  if (!ret) {
    ret = @[@0.75, @1, @1.25];
  }
  return ret;
}

- (void)setTimePlayed:(NSUInteger)timePlayed {
  [self setNeedsLayout];
  _timePlayed = timePlayed;
  [self updateProgressDuration];
}

- (void)setTimeTotal:(NSUInteger)timeTotal {
  [self setNeedsLayout];
  _timeTotal = timeTotal;
  [self updateProgressDuration];
}

- (void)updateProgressDuration {
  NSString *played = [self.class timeStringWithTimeInterval:self.timePlayed];
  NSString *total = [self.class timeStringWithTimeInterval:self.timeTotal];
  self.lbProgressDuration.text = [NSString stringWithFormat:@"%@ / %@", played, total];
}

- (void)syncUIWithPlayerState:(BOOL)isplaying {
  self.btPlay.selected = !isplaying;
}

+ (NSString *)timeStringWithTimeInterval:(int64_t)timeInterval {
  NSString *ret = nil;
  
  NSInteger hour = (NSInteger)timeInterval / 3600;
  NSInteger hourRemain = (NSInteger)timeInterval % 3600;
  NSInteger totalMin = (NSInteger)hourRemain / 60;
  NSInteger totalSec = (NSInteger)hourRemain % 60;
  
  if (hour == 0) {
    ret = [NSString stringWithFormat:@"%.2ld:%.2ld",(long)totalMin, (long)totalSec];
  } else {
    ret = [NSString stringWithFormat:@"%.2ld:%.2ld:%.2ld", (long)hour, (long)totalMin, (long)totalSec];
  }
  
  return ret;
  
}

@end
