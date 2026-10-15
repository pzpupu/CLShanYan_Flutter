#import "CLShanYanNativeStyle.h"
#import <objc/runtime.h>

/// 关联存储键只标记本 helper 的反馈控制器，不承载 SDK 业务状态。
static char CLShanYanButtonFeedbackKey;

@class CLShanYanButtonFeedback;
/// CADisplayLink 强持有 target；使用弱转发对象，页面销毁时无需等待下一帧打破持有环。
@interface CLShanYanPressFrameTarget : NSObject
@property(nonatomic,weak) CLShanYanButtonFeedback *feedback;
- (void)tick:(CADisplayLink *)link;
@end

/// 仅由按钮的关联对象持有；弱引用真实 UIButton，防止授权页关闭后形成持有环。
@interface CLShanYanButtonFeedback : NSObject
@property(nonatomic,weak) UIButton *button;
@property(nonatomic,strong) UIView *overlay;
@property(nonatomic,strong) CADisplayLink *trackingLink;
@property(nonatomic,strong) CLShanYanPressFrameTarget *frameTarget;
@property(nonatomic) CGAffineTransform restingTransform;
@property(nonatomic) CGFloat pressedScale;
@property(nonatomic) NSTimeInterval duration;
@property(nonatomic) BOOL pressed;
- (instancetype)initWithButton:(UIButton *)button;
- (void)updateOverlayColor:(UIColor *)color scale:(NSNumber *)scale duration:(NSNumber *)duration;
- (void)trackPress:(CADisplayLink *)link;
@end

@implementation CLShanYanPressFrameTarget
- (void)tick:(CADisplayLink *)link {
    [self.feedback trackPress:link];
}
@end

@implementation CLShanYanButtonFeedback
- (instancetype)initWithButton:(UIButton *)button {
    self = [super init];
    if (self) {
        _button = button;
        _restingTransform = button.transform;
        _frameTarget = [[CLShanYanPressFrameTarget alloc] init];
        _frameTarget.feedback = self;
        [button addTarget:self action:@selector(press:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [button addTarget:self action:@selector(release:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(applicationInactive:) name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_trackingLink invalidate];
}

/// 所有颜色由 UIView/UIColor 强持有，alpha 只存入颜色，静态按钮底色与文字颜色均不改。
- (void)updateOverlayColor:(UIColor *)color scale:(NSNumber *)scale duration:(NSNumber *)duration {
    self.pressedScale = scale ? MIN(1.0, MAX(0.001, scale.doubleValue)) : 1.0;
    self.duration = duration ? MAX(0.0, duration.doubleValue / 1000.0) : 0.2;
    if (color && !self.overlay) {
        UIView *overlay = [[UIView alloc] initWithFrame:self.button.bounds];
        overlay.userInteractionEnabled = NO;
        overlay.isAccessibilityElement = NO;
        overlay.accessibilityElementsHidden = YES;
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.alpha = 0.0;
        // titleLabel 是 UIButton 公开属性；将状态层放在文字下方，不改变文字本身的颜色。
        if (self.button.titleLabel.superview == self.button) {
            [self.button insertSubview:overlay belowSubview:self.button.titleLabel];
        } else {
            [self.button addSubview:overlay];
        }
        self.overlay = overlay;
    }
    self.overlay.backgroundColor = color;
    [self updateAppearanceAnimated:NO];
}

/// UIKit 不保证所有控件属性都可 KVO；仅按压期间逐帧观察 enabled，禁用立即恢复状态。
- (void)trackPress:(CADisplayLink *)link {
    UIButton *button = self.button;
    if (!button || !button.enabled || !button.window) {
        self.pressed = NO;
        [self stopTracking];
        [self updateAppearanceAnimated:NO];
    }
}

- (void)stopTracking {
    [self.trackingLink invalidate];
    self.trackingLink = nil;
}

- (void)press:(UIButton *)button {
    if (!button.enabled) {
        return;
    }
    self.pressed = YES;
    if (!self.trackingLink) {
        self.trackingLink = [CADisplayLink displayLinkWithTarget:self.frameTarget selector:@selector(tick:)];
        [self.trackingLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    [self updateAppearanceAnimated:YES];
}

- (void)release:(UIButton *)button {
    self.pressed = NO;
    [self stopTracking];
    [self updateAppearanceAnimated:YES];
}

- (void)applicationInactive:(NSNotification *)notification {
    self.pressed = NO;
    [self stopTracking];
    [self updateAppearanceAnimated:NO];
}

/// 不移除 SDK 的其他动画或事件；只更新本 helper 管理的 transform 与状态层透明度。
- (void)updateAppearanceAnimated:(BOOL)animated {
    UIButton *button = self.button;
    if (!button) {
        return;
    }
    BOOL pressed = self.pressed && button.enabled;
    CGFloat scale = pressed ? self.pressedScale : 1.0;
    self.overlay.frame = button.bounds;
    self.overlay.layer.cornerRadius = button.layer.cornerRadius;
    void (^changes)(void) = ^{
        button.transform = CGAffineTransformScale(self.restingTransform, scale, scale);
        self.overlay.alpha = pressed ? 1.0 : 0.0;
    };
    // SDK 可能在 TouchUpInside 的另一个 target 中禁用按钮；此时不等待释放动画完成。
    if (animated && button.enabled && self.duration > 0.0) {
        [UIView animateWithDuration:self.duration delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear animations:changes completion:nil];
    } else {
        [button.layer removeAnimationForKey:@"transform"];
        [self.overlay.layer removeAnimationForKey:@"opacity"];
        [UIView performWithoutAnimation:changes];
    }
}
@end

/// 只包装插件创建的背景装饰；内容继续负责填充/边框/圆角，外层独立绘制可越界阴影。
@interface CLShanYanShadowDecoration : UIView
@property(nonatomic,strong) UIView *content;
@property(nonatomic) CGFloat spreadRadius;
@property(nonatomic) CGFloat cardCornerRadius;
@property(nonatomic) CGRect lastShadowBounds;
@property(nonatomic) CGFloat lastShadowCornerRadius;
@property(nonatomic) CGFloat lastShadowSpreadRadius;
@end

@implementation CLShanYanShadowDecoration
- (void)layoutSubviews {
    [super layoutSubviews];
    self.content.frame = self.bounds;
    if (CGRectEqualToRect(self.lastShadowBounds, self.bounds) &&
        self.lastShadowCornerRadius == self.cardCornerRadius &&
        self.lastShadowSpreadRadius == self.spreadRadius) {
        return;
    }
    self.lastShadowBounds = self.bounds;
    self.lastShadowCornerRadius = self.cardCornerRadius;
    self.lastShadowSpreadRadius = self.spreadRadius;
    CGRect shadowBounds = CGRectInset(self.bounds, -self.spreadRadius, -self.spreadRadius);
    // 负 spread 收缩阴影轮廓而非卡片本体；收缩过度时不给无效尺寸绘制阴影。
    UIBezierPath *path = CGRectIsEmpty(shadowBounds) ? [UIBezierPath bezierPath] :
        [UIBezierPath bezierPathWithRoundedRect:shadowBounds cornerRadius:MAX(0.0, self.cardCornerRadius + self.spreadRadius)];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.shadowPath = path.CGPath;
    [CATransaction commit];
}
@end

@implementation CLShanYanNativeStyle
+ (void)applyToButton:(UIButton *)button overlayColor:(UIColor *)overlayColor pressedScale:(NSNumber *)pressedScale duration:(NSNumber *)durationMilliseconds {
    if (!overlayColor && !pressedScale && !durationMilliseconds) {
        return;
    }
    // 关联对象是公开运行时存储，不读取 SDK 私有状态；每个真实按钮只绑定一个控制器。
    CLShanYanButtonFeedback *feedback = objc_getAssociatedObject(button, &CLShanYanButtonFeedbackKey);
    if (!feedback) {
        feedback = [[CLShanYanButtonFeedback alloc] initWithButton:button];
        objc_setAssociatedObject(button, &CLShanYanButtonFeedbackKey, feedback, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [feedback updateOverlayColor:overlayColor scale:pressedScale duration:durationMilliseconds];
}

+ (UIView *)decorationWithContent:(UIView *)content shadowColor:(UIColor *)shadowColor blurRadius:(CGFloat)blurRadius spreadRadius:(CGFloat)spreadRadius offset:(CGSize)offset cornerRadius:(CGFloat)cornerRadius {
    CLShanYanShadowDecoration *decoration = [[CLShanYanShadowDecoration alloc] initWithFrame:content.frame];
    decoration.content = content;
    decoration.spreadRadius = spreadRadius;
    decoration.cardCornerRadius = cornerRadius;
    decoration.lastShadowBounds = CGRectNull;
    decoration.userInteractionEnabled = NO;
    decoration.isAccessibilityElement = NO;
    decoration.accessibilityElementsHidden = YES;
    decoration.layer.masksToBounds = NO;
    decoration.layer.shadowColor = shadowColor.CGColor;
    decoration.layer.shadowOpacity = 1.0f;
    // Flutter 的 blurRadius 先转换为 Gaussian sigma；Core Animation 合成仍需视觉核对，不承诺像素等价。
    decoration.layer.shadowRadius = blurRadius > 0.0 ? blurRadius * 0.57735 + 0.5 : 0.0;
    decoration.layer.shadowOffset = offset;
    [decoration addSubview:content];
    return decoration;
}

@end
