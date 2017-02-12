//
//  ZKEnlargeView.m
//  TappableViewContainer
//
//  Created by mac on 12/21/15.
//  Copyright © 2015 zhike. All rights reserved.
//

#import "ZKEnlargeView.h"

@interface ZKEnlargeView ()
@property (assign, nonatomic) CGSize minimumEffectSize;
@end

@implementation ZKEnlargeView

- (instancetype)initWithMinimumEffectSize:(CGSize)size {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _minimumEffectSize = size;
  }
  return self;
}

- (CGSize)minimumEffectSize {
  if (_minimumEffectSize.height > 0 && _minimumEffectSize.width > 0) {
    return _minimumEffectSize;
  }else {
    return CGSizeMake(MAX(_minimumEffectSize.width, 64), MAX(_minimumEffectSize.height, 64));
  }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  
  if (!CGRectContainsPoint(self.bounds, point)) {
    
    CGSize minSize = self.minimumEffectSize;
    
    if (self.bounds.size.width < minSize.width || self.bounds.size.height < minSize.height) {
      
      CGFloat insetH = (self.bounds.size.width - minSize.width) / 2.0;
      CGFloat insetW = (self.bounds.size.height - minSize.height) / 2.0;
      insetW = insetW > 0 ? 0 : insetW;
      insetH = insetH > 0 ? 0 : insetH;
      
      CGRect originRect = self.bounds;
      CGRect effectRect = CGRectInset(originRect, insetW, insetH);
      
      return CGRectContainsPoint(effectRect
                                 , point);
      
    }
    
  }
  
  return [super pointInside:point withEvent:event];
}

@end
