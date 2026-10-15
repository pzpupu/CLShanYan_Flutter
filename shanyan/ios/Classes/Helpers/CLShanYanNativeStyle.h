#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 只负责插件装饰和真实按钮的 UIKit 样式，不持有授权请求或改变 SDK 点击处理。
@interface CLShanYanNativeStyle : NSObject

/// 按钮自身保有反馈控制器；重复应用只更新参数，不重复注册 UIControl 事件。
+ (void)applyToButton:(UIButton *)button
        overlayColor:(nullable UIColor *)overlayColor
        pressedScale:(nullable NSNumber *)pressedScale
            duration:(nullable NSNumber *)durationMilliseconds;

/// 为插件自己的背景装饰增加独立阴影层；返回视图的 bounds 仍代表原卡片本体。
+ (UIView *)decorationWithContent:(UIView *)content
                     shadowColor:(UIColor *)shadowColor
                      blurRadius:(CGFloat)blurRadius
                    spreadRadius:(CGFloat)spreadRadius
                          offset:(CGSize)offset
                    cornerRadius:(CGFloat)cornerRadius;

@end

NS_ASSUME_NONNULL_END
