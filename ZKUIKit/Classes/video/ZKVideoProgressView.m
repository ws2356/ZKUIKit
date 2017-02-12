//
//  ZKVideoProgressView.m
//  ieltsmobile
//
//  Created by wansong on 16/6/6.
//  Copyright © 2016年 Facebook. All rights reserved.
//

#import "ZKVideoProgressView.h"
#import <AVFoundation/AVFoundation.h>
#import "Masonry.h"
#import "ZKTubeLikeView.h"

#define DOT_WIDTH 2
#define PROGRESS_HEIGHT 4

@interface ZKVideoProgressView ()

@property (strong, nonatomic) NSArray<UIView*> *loadedRanges;
@property (assign, nonatomic) float duration;

@property (readonly, nonatomic) UIView *rangesBackgroundView;
@property (readonly, nonatomic) ZKTubeLikeView *progressView;
@property (strong, nonatomic) MASConstraint *progressConstraint;

@end

@implementation ZKVideoProgressView {
  UIView *_rangesBackgroundView;
  ZKTubeLikeView *_progressView;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self configView];
  }
  return self;
}

- (void)configView {
  _rangesBackgroundView = [UIView new];
  NSAssert(self.rangesBackgroundView, @"");
  self.rangesBackgroundView.backgroundColor = [UIColor clearColor];
  [self addSubview:self.rangesBackgroundView];
  
  _progressView = [ZKTubeLikeView new];
  [self addSubview:self.progressView];
  
  //user of this view should use autolayout, or bad things would happen
  self.translatesAutoresizingMaskIntoConstraints = NO;
  [self.rangesBackgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.edges.equalTo(self);
    make.height.equalTo(@(PROGRESS_HEIGHT)).priorityMedium();;
  }];
  
  [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.top.and.leading.and.bottom.equalTo(self.rangesBackgroundView);
  }];
  
  [self setNeedsUpdateConstraints];
  
//#ifdef DEBUG
//  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//    self.dots = @[@0.1, @0.3, @0.8];
//  });
//#endif
  
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  
  CGFloat width = CGRectGetWidth(rect);
  CGFloat height = CGRectGetHeight(rect);
  
  //draw dots
  [[UIColor whiteColor] setFill];
  for (NSNumber *dot in self.dots) {
    CGFloat xi = width * dot.floatValue;
    CGRect endPointRect = CGRectMake(xi - DOT_WIDTH / 2.0, 0, DOT_WIDTH, height);
    CGContextFillRect(ctx, endPointRect);
  }
  
}

- (void)updateLoadedRanges:(NSArray<NSValue *> *)loadedRanges duration:(float)duration {
  if (duration <= 0 || !loadedRanges.count) {
    NSLog(@"loadedRanges: %@", loadedRanges);
  }
  
  self.duration = duration;
  NSArray<NSValue*> *ranges = [[self class] mergedRanges:loadedRanges];
  
  NSArray *views = nil;
  {
    for (UIView *aview in self.loadedRanges) {
      [aview removeFromSuperview];
    }
    
    NSMutableArray *temp = [NSMutableArray arrayWithArray:self.loadedRanges ?: @[]];
    if (temp.count < ranges.count) {
      NSInteger extra = ranges.count - temp.count;
      for (NSInteger i = 0; i < extra; i++) {
        UIView *aview = [[UIView alloc] init];
        aview.backgroundColor = [UIColor colorWithRed:0.7 green:.7 blue:.7 alpha:.3];
        [temp addObject:aview];
      }
      views = temp;
    }else {
      NSRange range;
      range.location = 0;
      range.length = ranges.count;
      views = [temp subarrayWithRange:range];
    }
  }
  self.loadedRanges = views;
  
  [self instalViews:views ranges:ranges];
  
  [self setNeedsLayout];
}

- (void)updateConstraints {
  [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
    make.updateExisting = YES;
    self.progressConstraint = make.width.equalTo(self.mas_width).multipliedBy(self.progress);
  }];
  
  [super updateConstraints];
}

- (void)setProgress:(CGFloat)progress {
  _progress = MIN(1, MAX(0, progress));
  [self.progressConstraint uninstall];
  [self setNeedsUpdateConstraints];
  [self.progressView setNeedsDisplay];
}

- (void)instalViews:(NSArray<UIView*> *)views ranges:(NSArray<NSValue*>*)ranges {
  
  for (NSInteger i = 0; i < views.count; i++) {
    UIView *aview = views[i];
    NSValue *range = ranges[i];
    Float64 start = CMTimeGetSeconds([range CMTimeRangeValue].start) / self.duration;
    Float64 dur = CMTimeGetSeconds([range CMTimeRangeValue].duration) / self.duration;
    
    NSAssert(start <= 1, @"");
    if (dur >= 1) {
      dur = 1;
    }
    
    [self.rangesBackgroundView addSubview:aview];
    
      [aview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.and.bottom.equalTo(self.rangesBackgroundView);
        if (start <= 0) {
          make.leading.equalTo(@0);
        }else {
          make.leading.equalTo(self.rangesBackgroundView.mas_trailing).multipliedBy(start);
        }
        make.width.equalTo(self.rangesBackgroundView.mas_width).multipliedBy(dur);
      }];
    
  }
  
}

//FIXME: add unit test
+ (NSArray*)mergedRanges:(NSArray*)ranges {
  ranges = [ranges sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
    NSValue *v1 = (NSValue*)obj1;
    NSValue *v2 = (NSValue*)obj2;
    Float64 v1_v2 = CMTimeGetSeconds([v1 CMTimeRangeValue].start)
    - CMTimeGetSeconds([v2 CMTimeRangeValue].start);
    
    if (v1_v2 < 0) {
      return NSOrderedAscending;
    }else if (v1_v2 > 0) {
      return NSOrderedDescending;
    }else {
      return NSOrderedSame;
    }
  }];
  
  NSMutableArray *ret = [NSMutableArray arrayWithCapacity:ranges.count];
  for (NSValue *rg in ranges) {
    if (!ret.count) {
      [ret addObject:rg];
    }else {
      CMTimeRange last = [(NSValue*)ret.lastObject CMTimeRangeValue];
      CMTimeRange cur = [rg CMTimeRangeValue];
      if (!CMTimeRangeContainsTime(last, cur.start)) {
        [ret addObject:rg];
      }else {
        CMTime curEnd = CMTimeAdd(cur.start, cur.duration);
        if (!CMTimeRangeContainsTime(last, curEnd)) {
          [ret removeLastObject];
          CMTimeRange last2 = CMTimeRangeMake(last.start, CMTimeSubtract(curEnd, last.start));
          [ret addObject:[NSValue valueWithCMTimeRange:last2]];
        }
      }
    }
  }
  
  return ret;
}

- (void)setDots:(NSArray<NSNumber *> *)dots {
  if (![_dots isEqual:dots]) {
    [self setNeedsDisplay];
  }
  _dots = dots;
}

@end
