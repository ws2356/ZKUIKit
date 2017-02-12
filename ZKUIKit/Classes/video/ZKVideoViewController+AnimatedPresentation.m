//
//  ZKVideoViewController+AnimatedPresentation.m
//  ServerInApp
//
//  Created by wansong on 2/8/17.
//  Copyright © 2017 zhike. All rights reserved.
//

#import "ZKVideoViewController+AnimatedPresentation.h"

@interface ZKVideoViewControllerAnimator: NSObject <UIViewControllerAnimatedTransitioning>
- (instancetype)initWithPresentingOrDismissing:(BOOL)isPresenting fromRect:(CGRect)fromRect;
@property (assign, nonatomic) BOOL isPresenting;
@property (assign, nonatomic) CGRect fromRect;
@property (strong, nonatomic) id <UIViewControllerContextTransitioning> transitionContext;
@end

@implementation ZKVideoViewControllerAnimator
- (instancetype)initWithPresentingOrDismissing:(BOOL)isPresenting fromRect:(CGRect)fromRect {
  self = [super init];
  if (self) {
    _isPresenting = isPresenting;
    _fromRect = fromRect;
  }
  return self;
}

- (NSTimeInterval)transitionDuration:(nullable id <UIViewControllerContextTransitioning>)transitionContext {
  return 0.5;
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext{
  self.transitionContext = transitionContext;
  UIView *containterView = [transitionContext containerView];
  UIViewController *from = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
  UIViewController *to = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
  UIView *fromView = from.view;
  UIView *toView = to.view;
  CGRect bounds = containterView.bounds;
  if (self.isPresenting) {
    CGRect screen = [UIScreen mainScreen].bounds;
    toView.frame = screen;
    toView.transform = [[self class] landscapeFullscreenToInitFrame:
                        [[self class] mirrorFrameInLandscapeScreen:self.fromRect]];
    [containterView insertSubview:toView aboveSubview:fromView];
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                     animations:^{
                       toView.transform = CGAffineTransformIdentity;
                     }
                     completion:^(BOOL finished) {
                       [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
                     }];
  } else {
    CGRect finalFrame = self.fromRect;
    [[self class] swapNumber1:&finalFrame.size.width number2:&finalFrame.size.height];
    fromView.frame = finalFrame;
    fromView.center = CGPointMake(CGRectGetMidX(self.fromRect), CGRectGetMidY(self.fromRect));
    fromView.transform = [[self class] initFrameToFullscreenTransform:fromView.frame];
    [containterView bringSubviewToFront:fromView];
    [containterView insertSubview:toView belowSubview:fromView];
    toView.frame = bounds;
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                     animations:^{
                       fromView.transform = CGAffineTransformIdentity;
                     }
                     completion:^(BOOL finished) {
                       [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
                     }];
  }
}

- (void)animationEnded:(BOOL)transitionCompleted {
  // no need, because not interactive animation
}

+ (CGRect)mirrorFrameInLandscapeScreen:(CGRect)portraitFrame {
  CGRect ret = portraitFrame;
  CGRect screen = [UIScreen mainScreen].bounds;
  if (CGRectGetWidth(screen) > CGRectGetHeight(screen)) {
    [self swapNumber1:&screen.size.width number2:&screen.size.height];
  }
  [self swapNumber1:&ret.size.width number2:&ret.size.height];
  ret.origin.x = CGRectGetMidY(portraitFrame) - CGRectGetHeight(portraitFrame) / 2.;
  ret.origin.y =  CGRectGetWidth(screen) - CGRectGetMidX(portraitFrame) - CGRectGetWidth(portraitFrame) / 2.;
  return ret;
}

+ (CGAffineTransform)initFrameToFullscreenTransform:(CGRect)initFrame {
  CGRect screen = [UIScreen mainScreen].bounds;
  if (CGRectGetWidth(screen) > CGRectGetHeight(screen)) {
    [self swapNumber1:&screen.size.width number2:&screen.size.height];
  }
  CGAffineTransform ret =
  CGAffineTransformMakeTranslation(
                                   CGRectGetMidX(screen) - CGRectGetMidX(initFrame),
                                   CGRectGetMidY(screen) - CGRectGetMidY(initFrame));
  ret = CGAffineTransformRotate(ret, M_PI_2);
  ret = CGAffineTransformScale(ret,
                               CGRectGetHeight(screen) / CGRectGetHeight(initFrame),
                               CGRectGetWidth(screen) / CGRectGetWidth(initFrame)
                               );
  return ret;
}

+ (CGAffineTransform)landscapeFullscreenToInitFrame:(CGRect)initFrame {
  CGRect screen = [UIScreen mainScreen].bounds;
  if (CGRectGetWidth(screen) > CGRectGetHeight(screen)) {
    [self swapNumber1:&screen.size.width number2:&screen.size.height];
  }
  CGAffineTransform ret =
  CGAffineTransformMakeTranslation(
                                   -CGRectGetMidY(screen) + CGRectGetMidX(initFrame),
                                   -CGRectGetMidX(screen) + CGRectGetMidY(initFrame));
  ret = CGAffineTransformRotate(ret, -M_PI_2);
  ret = CGAffineTransformScale(ret,
                               CGRectGetHeight(initFrame) / CGRectGetHeight(screen),
                               CGRectGetWidth(initFrame) / CGRectGetWidth(screen)
                               );
  return ret;
}

+(void)swapNumber1:(CGFloat* )number1 number2:(CGFloat *)number2 {
  *number1 -= *number2;
  *number2 += *number1;
  *number1 = *number2 - *number1;
}
@end

@interface ZKVideoViewController ()
@property (assign, nonatomic) CGRect fromRect;
@end

@implementation ZKVideoViewController (AnimatedPresentation)
- (nullable id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                            presentingController:(UIViewController *)presenting
                                                                                sourceController:(UIViewController *)source {
  return [[ZKVideoViewControllerAnimator alloc] initWithPresentingOrDismissing:YES fromRect:self.fromRect];
}

- (nullable id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
  return [[ZKVideoViewControllerAnimator alloc] initWithPresentingOrDismissing:NO fromRect:self.fromRect];
}

@end
