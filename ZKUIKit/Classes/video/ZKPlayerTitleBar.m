//
//  ZKPlayerTitleBar.m
//  ieltsmobile
//
//  Created by wansong on 16/6/5.
//  Copyright © 2016年 Facebook. All rights reserved.
//

#import "ZKPlayerTitleBar.h"
#import "ZKEnlargeView.h"
#import "Masonry.h"
#import "ZKUIKitResourceManager.h"

@interface ZKPlayerTitleBar ()
@property (strong, nonatomic) UILabel *titleLabel;
@end

@implementation ZKPlayerTitleBar

- (instancetype)initWithFrame:(CGRect)frame topReserve:(CGFloat)topReserve {
  self = [super initWithFrame:frame];
  if (self) {
    [self setupSubviews:topReserve];
  }
  return self;
}

- (void)setupSubviews:(CGFloat)topReserve {
  self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
  UIButton *backButton = [[ZKEnlargeView alloc] initWithMinimumEffectSize:CGSizeMake(40, 40)];
  UILabel *titleLabel = [UILabel new];
  titleLabel.textColor = [UIColor whiteColor];
  self.titleLabel = titleLabel;
  titleLabel.userInteractionEnabled = YES;
  
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(backButtonTapAction:)];
  [titleLabel addGestureRecognizer:tap];
  
  [backButton setImage:[UIImage imageNamed:@"ic-back-white" inBundle:[ZKUIKitResourceManager resourceBundle] compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
  [backButton addTarget:self action:@selector(backButtonTapAction:) forControlEvents:UIControlEventTouchUpInside];
  
  const CGFloat left = 10;
  const CGFloat spacingH = 10;
  [self addSubview:backButton];
  [self addSubview:titleLabel];
  
  [backButton mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(self.mas_centerY).offset(topReserve/2.0);
    make.leading.equalTo(self.mas_leading).offset(left);
  }];
  [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
    make.centerY.equalTo(backButton.mas_centerY);
    make.leading.equalTo(backButton.mas_trailing).offset(spacingH);
  }];
  
}

- (void)setTitle:(NSString *)title {
  self.titleLabel.text = title ?: @"";
  [self setNeedsLayout];
}

- (NSString*)title {
  return self.titleLabel.text;
}

- (void)backButtonTapAction:(UIButton*)sender {
  self.backButtonAtion();
}
@end
