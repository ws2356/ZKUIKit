//
//  TableViewCell.m
//  ServerInApp
//
//  Created by wansong.mbp.work on 04/02/2017.
//  Copyright © 2017 zhike. All rights reserved.
//

#import "TableViewCell.h"


@interface TableViewCell ()
@property (strong, nonatomic) ZKVideoView *videoView;
@property (copy, nonatomic) NSString *urlString;
@property (assign, nonatomic) BOOL on;
@end

@interface ZKVideoView ()
- (void)setPlayerState:(PlayerState)playerState;
@end

@implementation TableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    self.backgroundColor = [UIColor redColor];
    self.contentView.backgroundColor = [UIColor redColor];
  }
  return self;
}

- (void)layoutSubviews {
  CGRect bounds = self.bounds;
  CGRect videoFrame = CGRectInset(bounds, 0, 5);
  self.videoView.frame = videoFrame;
  self.videoView.backgroundColor = [UIColor blackColor];
}

- (void)setVideoInfo:(NSDictionary *)videoInfo {
  self.urlString = videoInfo[@"url"];
  self.on = [videoInfo[@"on"] boolValue];
  _videoInfo = [videoInfo copy];
  [self.contentView setNeedsLayout];
}

- (void)setOn:(BOOL)on {
  if (on) {
    self.videoView.playerState = PlayerStatePlaying;
  } else {
    self.videoView.playerState = PlayerStatePaused;
  }
}

- (BOOL)on {
  return self.videoView.playerState == PlayerStatePlaying;
}

- (void)setUrlString:(NSString *)urlString {
  if (![urlString isEqualToString:self.urlString]) {
    self.on = NO;
  }
  self.videoView.source = urlString;
}

- (NSString*)urlString {
  return self.videoView.source;
}

- (ZKVideoView*)videoView {
  if (!_videoView) {
    _videoView = [ZKVideoView new];
    [self.contentView addSubview:_videoView];
  }
  return _videoView;
}

@end
