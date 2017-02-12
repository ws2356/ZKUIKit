//
//  ZKTubeLikeView.m
//  testCustomedAnimatableLayer
//
//  Created by wansong on 15/12/10.
//  Copyright © 2015年 zhike. All rights reserved.
//

#import "ZKTubeLikeView.h"
#import "Masonry.h"

@implementation ZKTubeLikeView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self configAppearance];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder*)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self configAppearance];
  }
  return self;
}

- (void)configAppearance {
  self.backgroundColor = [UIColor clearColor];
}

- (void)drawRect:(CGRect)rect {
  CGPoint startPoint = CGPointZero;
  CGFloat radius = rect.size.height / 2.0f;
  
  UIBezierPath *path = [UIBezierPath bezierPath];
  [path moveToPoint:startPoint];
  
  CGPoint topRight = startPoint;
  topRight.x += rect.size.width - radius;
  [path addLineToPoint:topRight];
  
  CGPoint arcCenter = topRight;
  arcCenter.y += radius;
  [path addArcWithCenter:arcCenter
                  radius:radius
              startAngle:-M_PI_2
                endAngle:M_PI_2
               clockwise:YES];
  
  CGPoint botLeft = startPoint;
  botLeft.y += rect.size.height;
  [path addLineToPoint:botLeft];
  
  [path closePath];
  [path addClip];
  
  [[UIColor orangeColor] setFill];
  
  [path fill];
}

@end
