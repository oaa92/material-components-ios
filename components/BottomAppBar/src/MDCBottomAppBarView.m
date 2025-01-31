// Copyright 2017-present the Material Components for iOS authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <CoreGraphics/CoreGraphics.h>

#import "MDCBottomAppBarView.h"

#import "private/MDCBottomAppBarAttributes.h"
#import "private/MDCBottomAppBarLayer.h"
#import "MaterialButtons.h"
#import "MaterialElevation.h"
#import "MaterialNavigationBar.h"
#import "MaterialShadowElevations.h"
#import "MaterialMath.h"

static NSString *kMDCBottomAppBarViewAnimKeyString = @"AnimKey";
static NSString *kMDCBottomAppBarViewPathString = @"path";
static NSString *kMDCBottomAppBarViewPositionString = @"position";
static const CGFloat kMDCBottomAppBarViewFloatingButtonCenterToNavigationBarTopOffset = 0;
static const CGFloat kMDCBottomAppBarViewFloatingButtonElevationPrimary = 6;
static const CGFloat kMDCBottomAppBarViewFloatingButtonElevationSecondary = 4;

@interface MDCBottomAppBarCutView : UIView

@end

@implementation MDCBottomAppBarCutView

// Allows touch events to pass through so MDCBottomAppBarController can handle touch events.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  UIView *view = [super hitTest:point withEvent:event];
  return (view == self) ? nil : view;
}

@end

@interface MDCBottomAppBarView () <CAAnimationDelegate>

@property(nonatomic, assign) CGFloat bottomBarHeight;
@property(nonatomic, strong) MDCBottomAppBarCutView *cutView;
@property(nonatomic, strong) MDCBottomAppBarLayer *bottomBarLayer;
@property(nonatomic, strong) MDCNavigationBar *navBar;

@end

@implementation MDCBottomAppBarView

@synthesize mdc_overrideBaseElevation = _mdc_overrideBaseElevation;
@synthesize mdc_elevationDidChangeBlock = _mdc_elevationDidChangeBlock;

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self commonMDCBottomAppBarViewInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self commonMDCBottomAppBarViewInit];
  }
  return self;
}

- (void)commonMDCBottomAppBarViewInit {
  self.cutView = [[MDCBottomAppBarCutView alloc] initWithFrame:self.bounds];
  self.floatingButtonVerticalOffset =
      kMDCBottomAppBarViewFloatingButtonCenterToNavigationBarTopOffset;
  [self addSubview:self.cutView];

  self.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin |
                           UIViewAutoresizingFlexibleRightMargin);

  [self addFloatingButton];
  [self addBottomBarLayer];
  [self addNavBar];

  self.barTintColor = UIColor.whiteColor;
  self.shadowColor = UIColor.blackColor;
  _elevation = MDCShadowElevationBottomAppBar;
  _mdc_overrideBaseElevation = -1;
}

- (CGSize)intrinsicContentSize {
  return CGSizeMake(UIViewNoIntrinsicMetric, kMDCBottomAppBarHeight);
}

- (void)addFloatingButton {
  MDCFloatingButton *floatingButton = [[MDCFloatingButton alloc] init];
  [self setFloatingButton:floatingButton];
  [self setFloatingButtonPosition:MDCBottomAppBarFloatingButtonPositionCenter];
  [self setFloatingButtonElevation:MDCBottomAppBarFloatingButtonElevationPrimary];
  [self setFloatingButtonHidden:NO];
}

- (void)addNavBar {
  _navBar = [[MDCNavigationBar alloc] initWithFrame:CGRectZero];
  [self addSubview:_navBar];

  _navBar.backgroundColor = [UIColor clearColor];
  _navBar.tintColor = [UIColor blackColor];
  _navBar.leadingBarItemsTintColor = UIColor.blackColor;
  _navBar.trailingBarItemsTintColor = UIColor.blackColor;
}

- (void)addBottomBarLayer {
  if (_bottomBarLayer) {
    [_bottomBarLayer removeFromSuperlayer];
  }
  _bottomBarLayer = [MDCBottomAppBarLayer layer];
  [_cutView.layer addSublayer:_bottomBarLayer];
}

- (void)renderPathBasedOnFloatingButtonVisibitlityAnimated:(BOOL)animated {
  if (!self.floatingButtonHidden) {
    [self cutBottomAppBarViewAnimated:animated];
  } else {
    [self healBottomAppBarViewAnimated:animated];
  }
}

- (CGPoint)getFloatingButtonCenterPositionForAppBarWidth:(CGFloat)appBarWidth {
  CGPoint floatingButtonPoint = CGPointZero;
  CGFloat navigationBarMinY = CGRectGetMinY(self.navBar.frame);
  floatingButtonPoint.y = MAX(0, navigationBarMinY - self.floatingButtonVerticalOffset);

  UIEdgeInsets safeAreaInsets = UIEdgeInsetsZero;
  if (@available(iOS 11.0, *)) {
    safeAreaInsets = self.safeAreaInsets;
  }

  CGFloat leftCenter = kMDCBottomAppBarFloatingButtonPositionX + safeAreaInsets.left;
  CGFloat rightCenter =
      appBarWidth - kMDCBottomAppBarFloatingButtonPositionX - safeAreaInsets.right;
  BOOL isRTL =
      self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
  switch (self.floatingButtonPosition) {
    case MDCBottomAppBarFloatingButtonPositionLeading: {
      floatingButtonPoint.x = isRTL ? rightCenter : leftCenter;
      break;
    }
    case MDCBottomAppBarFloatingButtonPositionCenter: {
      floatingButtonPoint.x = appBarWidth / 2;
      break;
    }
    case MDCBottomAppBarFloatingButtonPositionTrailing: {
      floatingButtonPoint.x = isRTL ? leftCenter : rightCenter;
      break;
    }
    default:
      break;
  }

  return floatingButtonPoint;
}

- (void)cutBottomAppBarViewAnimated:(BOOL)animated {
  CGPathRef pathWithCut = [self.bottomBarLayer pathFromRect:self.bounds
                                             floatingButton:self.floatingButton
                                         navigationBarFrame:self.navBar.frame
                                                  shouldCut:YES];
  if (animated) {
    CABasicAnimation *pathAnimation =
        [CABasicAnimation animationWithKeyPath:kMDCBottomAppBarViewPathString];
    pathAnimation.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    pathAnimation.duration = kMDCFloatingButtonExitDuration;
    pathAnimation.fromValue = (id)self.bottomBarLayer.presentationLayer.path;
    pathAnimation.toValue = (__bridge id _Nullable)(pathWithCut);
    pathAnimation.fillMode = kCAFillModeForwards;
    pathAnimation.removedOnCompletion = NO;
    pathAnimation.delegate = self;
    [pathAnimation setValue:kMDCBottomAppBarViewPathString
                     forKey:kMDCBottomAppBarViewAnimKeyString];
    [self.bottomBarLayer addAnimation:pathAnimation forKey:kMDCBottomAppBarViewPathString];
  } else {
    self.bottomBarLayer.path = pathWithCut;
  }
}

- (void)healBottomAppBarViewAnimated:(BOOL)animated {
  CGPathRef pathWithoutCut = [self.bottomBarLayer pathFromRect:self.bounds
                                                floatingButton:self.floatingButton
                                            navigationBarFrame:self.navBar.frame
                                                     shouldCut:NO];
  if (animated) {
    CABasicAnimation *pathAnimation =
        [CABasicAnimation animationWithKeyPath:kMDCBottomAppBarViewPathString];
    pathAnimation.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    pathAnimation.duration = kMDCFloatingButtonEnterDuration;
    pathAnimation.fromValue = (id)self.bottomBarLayer.presentationLayer.path;
    pathAnimation.toValue = (__bridge id _Nullable)(pathWithoutCut);
    pathAnimation.fillMode = kCAFillModeForwards;
    pathAnimation.removedOnCompletion = NO;
    pathAnimation.delegate = self;
    [pathAnimation setValue:kMDCBottomAppBarViewPathString
                     forKey:kMDCBottomAppBarViewAnimKeyString];
    [self.bottomBarLayer addAnimation:pathAnimation forKey:kMDCBottomAppBarViewPathString];
  } else {
    self.bottomBarLayer.path = pathWithoutCut;
  }
}

- (void)moveFloatingButtonCenterAnimated:(BOOL)animated {
  CGPoint endPoint =
      [self getFloatingButtonCenterPositionForAppBarWidth:CGRectGetWidth(self.bounds)];
  if (animated) {
    CABasicAnimation *animation =
        [CABasicAnimation animationWithKeyPath:kMDCBottomAppBarViewPositionString];
    animation.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.duration = kMDCFloatingButtonExitDuration;
    animation.fromValue = [NSValue valueWithCGPoint:self.floatingButton.center];
    animation.toValue = [NSValue valueWithCGPoint:endPoint];
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    animation.delegate = self;
    [animation setValue:kMDCBottomAppBarViewPositionString
                 forKey:kMDCBottomAppBarViewAnimKeyString];
    [self.floatingButton.layer addAnimation:animation forKey:kMDCBottomAppBarViewPositionString];
  }
  self.floatingButton.center = endPoint;
}

- (void)showBarButtonItemsWithFloatingButtonPosition:
    (MDCBottomAppBarFloatingButtonPosition)floatingButtonPosition {
  switch (floatingButtonPosition) {
    case MDCBottomAppBarFloatingButtonPositionCenter:
      [self.navBar setLeadingBarButtonItems:_leadingBarButtonItems];
      [self.navBar setTrailingBarButtonItems:_trailingBarButtonItems];
      break;
    case MDCBottomAppBarFloatingButtonPositionLeading:
      [self.navBar setLeadingBarButtonItems:nil];
      [self.navBar setTrailingBarButtonItems:_trailingBarButtonItems];
      break;
    case MDCBottomAppBarFloatingButtonPositionTrailing:
      [self.navBar setLeadingBarButtonItems:_leadingBarButtonItems];
      [self.navBar setTrailingBarButtonItems:nil];
      break;
    default:
      break;
  }
}

#pragma mark - UIView overrides

- (void)layoutSubviews {
  [super layoutSubviews];

  CGRect navBarFrame =
      CGRectMake(0, kMDCBottomAppBarNavigationViewYOffset, CGRectGetWidth(self.bounds),
                 kMDCBottomAppBarHeight - kMDCBottomAppBarNavigationViewYOffset);
  self.navBar.frame = navBarFrame;

  self.floatingButton.center =
      [self getFloatingButtonCenterPositionForAppBarWidth:CGRectGetWidth(self.bounds)];
  [self renderPathBasedOnFloatingButtonVisibitlityAnimated:NO];

  self.bottomBarLayer.fillColor = self.barTintColor.CGColor;
  self.bottomBarLayer.shadowColor = self.shadowColor.CGColor;
}

- (UIEdgeInsets)mdc_safeAreaInsets {
  UIEdgeInsets insets = UIEdgeInsetsZero;
  if (@available(iOS 11.0, *)) {
    // Accommodate insets for iPhone X.
    insets = self.safeAreaInsets;
  }
  return insets;
}

- (CGSize)sizeThatFits:(CGSize)size {
  UIEdgeInsets insets = self.mdc_safeAreaInsets;
  CGFloat heightWithInset = kMDCBottomAppBarHeight + insets.bottom;
  CGSize insetSize = CGSizeMake(size.width, heightWithInset);
  return insetSize;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  // Make sure the floating button can always be tapped.
  BOOL contains = CGRectContainsPoint(self.floatingButton.frame, point);
  if (contains) {
    return self.floatingButton;
  }
  UIView *view = [super hitTest:point withEvent:event];
  // Only subviews can receive events.
  return (view == self) ? nil : view;
}

#pragma mark - CAAnimationDelegate

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)flag {
  if (flag) {
    [self renderPathBasedOnFloatingButtonVisibitlityAnimated:NO];
    NSString *animValueForKeyString = [animation valueForKey:kMDCBottomAppBarViewAnimKeyString];
    if ([animValueForKeyString isEqualToString:kMDCBottomAppBarViewPathString]) {
      [self.bottomBarLayer removeAnimationForKey:kMDCBottomAppBarViewPathString];
    } else if ([animValueForKeyString isEqualToString:kMDCBottomAppBarViewPositionString]) {
      [self.floatingButton.layer removeAnimationForKey:kMDCBottomAppBarViewPositionString];
    }
  }
}

#pragma mark - Setters

- (void)setElevation:(MDCShadowElevation)elevation {
  if (MDCCGFloatEqual(elevation, _elevation)) {
    return;
  }
  _elevation = elevation;
  [self mdc_elevationDidChange];
}

- (void)setFloatingButton:(MDCFloatingButton *)floatingButton {
  if (_floatingButton == floatingButton) {
    return;
  }
  [_floatingButton removeFromSuperview];
  _floatingButton = floatingButton;
  _floatingButton.translatesAutoresizingMaskIntoConstraints = NO;
  [_floatingButton sizeToFit];
}

- (void)setFloatingButtonElevation:(MDCBottomAppBarFloatingButtonElevation)floatingButtonElevation {
  [self setFloatingButtonElevation:floatingButtonElevation animated:NO];
}

- (void)setFloatingButtonElevation:(MDCBottomAppBarFloatingButtonElevation)floatingButtonElevation
                          animated:(BOOL)animated {
  if (_floatingButton.superview == self && _floatingButtonElevation == floatingButtonElevation) {
    return;
  }
  _floatingButtonElevation = floatingButtonElevation;

  CGFloat elevation = kMDCBottomAppBarViewFloatingButtonElevationPrimary;
  NSInteger subViewIndex = 1;
  if (floatingButtonElevation == MDCBottomAppBarFloatingButtonElevationSecondary) {
    elevation = kMDCBottomAppBarViewFloatingButtonElevationSecondary;
    subViewIndex = 0;
  }
  // Immediately move the button to the correct z-ordering so that the shadow clipping effect isn't
  // as apparent. If we did this at the end of the animation, then the shadow would appear to
  // suddenly clip at the end of the animation.
  [self insertSubview:_floatingButton atIndex:subViewIndex];
  [_floatingButton setElevation:elevation forState:UIControlStateNormal];
}

- (void)setFloatingButtonPosition:(MDCBottomAppBarFloatingButtonPosition)floatingButtonPosition {
  [self setFloatingButtonPosition:floatingButtonPosition animated:NO];
}

- (void)setFloatingButtonPosition:(MDCBottomAppBarFloatingButtonPosition)floatingButtonPosition
                         animated:(BOOL)animated {
  if (_floatingButtonPosition == floatingButtonPosition) {
    return;
  }
  _floatingButtonPosition = floatingButtonPosition;
  [self moveFloatingButtonCenterAnimated:animated];
  [self renderPathBasedOnFloatingButtonVisibitlityAnimated:animated];
  [self showBarButtonItemsWithFloatingButtonPosition:floatingButtonPosition];
}

- (void)setFloatingButtonHidden:(BOOL)floatingButtonHidden {
  [self setFloatingButtonHidden:floatingButtonHidden animated:NO];
}

- (void)setFloatingButtonHidden:(BOOL)floatingButtonHidden animated:(BOOL)animated {
  if (_floatingButtonHidden == floatingButtonHidden) {
    return;
  }
  _floatingButtonHidden = floatingButtonHidden;
  if (floatingButtonHidden) {
    [self healBottomAppBarViewAnimated:animated];
    [_floatingButton collapse:animated
                   completion:^{
                     self.floatingButton.hidden = YES;
                   }];
  } else {
    _floatingButton.hidden = NO;
    [self cutBottomAppBarViewAnimated:animated];
    [_floatingButton expand:animated completion:nil];
  }
}

- (void)setLeadingBarButtonItems:(NSArray<UIBarButtonItem *> *)leadingBarButtonItems {
  _leadingBarButtonItems = [leadingBarButtonItems copy];
  [self showBarButtonItemsWithFloatingButtonPosition:self.floatingButtonPosition];
}

- (void)setTrailingBarButtonItems:(NSArray<UIBarButtonItem *> *)trailingBarButtonItems {
  _trailingBarButtonItems = [trailingBarButtonItems copy];
  [self showBarButtonItemsWithFloatingButtonPosition:self.floatingButtonPosition];
}

- (void)setBarTintColor:(UIColor *)barTintColor {
  _barTintColor = barTintColor;
  _bottomBarLayer.fillColor = barTintColor.CGColor;
}

- (void)setLeadingBarItemsTintColor:(UIColor *)leadingBarItemsTintColor {
  NSParameterAssert(leadingBarItemsTintColor);
  if (!leadingBarItemsTintColor) {
    leadingBarItemsTintColor = UIColor.blackColor;
  }
  self.navBar.leadingBarItemsTintColor = leadingBarItemsTintColor;
}

- (UIColor *)leadingBarItemsTintColor {
  return self.navBar.leadingBarItemsTintColor;
}

- (void)setTrailingBarItemsTintColor:(UIColor *)trailingBarItemsTintColor {
  NSParameterAssert(trailingBarItemsTintColor);
  if (!trailingBarItemsTintColor) {
    trailingBarItemsTintColor = UIColor.blackColor;
  }
  self.navBar.trailingBarItemsTintColor = trailingBarItemsTintColor;
}

- (UIColor *)trailingBarItemsTintColor {
  return self.navBar.trailingBarItemsTintColor;
}

- (void)setShadowColor:(UIColor *)shadowColor {
  _shadowColor = shadowColor;
  _bottomBarLayer.shadowColor = shadowColor.CGColor;
}

- (void)setRippleColor:(UIColor *)rippleColor {
  _rippleColor = [rippleColor copy];
  self.navBar.rippleColor = _rippleColor;
}

- (BOOL)enableRippleBehavior {
  return self.navBar.enableRippleBehavior;
}

- (void)setEnableRippleBehavior:(BOOL)enableRippleBehavior {
  self.navBar.enableRippleBehavior = enableRippleBehavior;
}

#pragma mark TraitCollection

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];

  if (self.traitCollectionDidChangeBlock) {
    self.traitCollectionDidChangeBlock(self, previousTraitCollection);
  }
}

#pragma mark - MDCElevation

- (CGFloat)mdc_currentElevation {
  return self.elevation;
}

@end
