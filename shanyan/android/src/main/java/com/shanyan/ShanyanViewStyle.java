package com.shanyan;

import android.animation.Animator;
import android.animation.AnimatorSet;
import android.animation.ObjectAnimator;
import android.animation.StateListAnimator;
import android.content.res.ColorStateList;
import android.graphics.BlurMaskFilter;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.RectF;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.os.Build;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.LinearInterpolator;
import android.widget.Button;
import android.widget.TextView;

import java.util.List;
import java.util.Map;

/** 授权页原生控件的内部绘制与状态样式；不接管 SDK 的点击、触摸或认证监听器。 */
final class ShanyanViewStyle {
    private static final int[] PRESSED = {android.R.attr.state_enabled, android.R.attr.state_pressed};
    private static final int[] HOVERED = {android.R.attr.state_enabled, android.R.attr.state_hovered};
    private static final int[] DISABLED = {-android.R.attr.state_enabled};
    private static final int[] NORMAL = {};

    private ShanyanViewStyle() {
    }

    /** 仅在新增字段出现时扩展自定义控件，缺省消费者仍使用原来的背景和交互。 */
    static void applyCustomWidget(TextView view, Map config) {
        float density = view.getResources().getDisplayMetrics().density;
        float radius = number(config, "cornerRadius", 0f) * density;
        boolean decoration = Boolean.TRUE.equals(config.get("isBackground"));
        boolean hasShadow = decoration && config.get("shadowColor") != null;
        boolean hasShape = hasShadow || config.get("cornerRadius") != null
                || config.get("borderWidth") != null || config.get("borderColor") != null;
        if (hasShape) {
            int fill = color(config, "backgroundColor", Color.TRANSPARENT);
            int border = color(config, "borderColor", Color.TRANSPARENT);
            float borderWidth = number(config, "borderWidth", 0f) * density;
            if (hasShadow) {
                CardSurfaceDrawable surface = new CardSurfaceDrawable(config, density, fill, border, borderWidth, radius);
                // 软件层只用于这个不可交互装饰，保证 API26–27 的 BlurMaskFilter 也可绘制。
                view.setLayerType(View.LAYER_TYPE_SOFTWARE, null);
                ViewGroup.LayoutParams params = view.getLayoutParams();
                int previousInset = view.getBackground() instanceof CardSurfaceDrawable
                        ? ((CardSurfaceDrawable) view.getBackground()).inset : 0;
                int extra = surface.inset - previousInset;
                if (params.width > 0) params.width += 2 * extra;
                if (params.height > 0) params.height += 2 * extra;
                if (params instanceof ViewGroup.MarginLayoutParams) {
                    ViewGroup.MarginLayoutParams margins = (ViewGroup.MarginLayoutParams) params;
                    margins.leftMargin -= extra;
                    margins.rightMargin -= extra;
                    margins.topMargin -= extra;
                    margins.bottomMargin -= extra;
                }
                view.setLayoutParams(params);
                view.setBackground(surface);
                // 阴影画在本控件预留的外延里，elevation 保持零，SDK 的背景索引 0 不变。
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    view.setStateListAnimator(null);
                    view.setElevation(0f);
                    view.setTranslationZ(0f);
                }
            } else {
                GradientDrawable surface = shape(fill, radius);
                surface.setStroke(Math.round(borderWidth), border);
                view.setBackground(surface);
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                view.setBackgroundTintList(null);
            }
        }
        if (!(view instanceof Button) || decoration) {
            return;
        }
        ButtonInteraction interaction = new ButtonInteraction(config, false);
        if (interaction.hasChanges() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            // 新的透明文字按钮没有常驻 elevation，不继承系统 Button 默认凸起效果。
            view.setElevation(0f);
            view.setTranslationZ(0f);
        }
        interaction.apply(view, radius);
        // 状态 drawable 安装后再落实内边距，避免背景自身 padding 覆盖 textButtonTheme 的配置。
        List<Number> padding = (List<Number>) config.get("contentPadding");
        if (padding != null) {
            view.setPadding(Math.round(padding.get(0).floatValue() * density),
                    Math.round(padding.get(1).floatValue() * density),
                    Math.round(padding.get(2).floatValue() * density),
                    Math.round(padding.get(3).floatValue() * density));
            view.setMinWidth(Math.round(44 * density));
            view.setMinHeight(Math.round(44 * density));
            view.setMinimumWidth(Math.round(44 * density));
            view.setMinimumHeight(Math.round(44 * density));
        }
    }

    /** 保存独立于 Activity 的按钮配置，重复应用不会嵌套水波背景或叠加触摸监听器。 */
    static final class ButtonInteraction {
        private final Float scale;
        private final Integer overlay;
        private final int duration;

        ButtonInteraction(Map config, boolean login) {
            String scaleKey = login ? "setLogBtnPressedScale" : "pressedScale";
            String colorKey = login ? "setLogBtnPressedOverlayColor" : "pressedOverlayColor";
            String durationKey = login ? "setLogBtnAnimationDuration" : "animationDuration";
            Number value = config == null ? null : (Number) config.get(scaleKey);
            scale = value == null ? null : value.floatValue();
            String color = config == null ? null : (String) config.get(colorKey);
            overlay = color == null ? null : Color.parseColor(color);
            duration = config == null ? 0 : Math.max(0, Math.round(number(config, durationKey, 0f)));
        }

        boolean hasChanges() {
            return scale != null || overlay != null;
        }

        /** 原生水波和状态缩放始终按配置工作，系统动画比例交由 Android 框架处理。 */
        void apply(View view, Float cornerRadius) {
            if (!hasChanges() || Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return;
            if (overlay != null) {
                Drawable base = view.getBackground();
                if (base instanceof ButtonRippleDrawable) base = ((ButtonRippleDrawable) base).base;
                if (base == null) base = new ColorDrawable(Color.TRANSPARENT);
                Drawable mask;
                if (cornerRadius != null) {
                    mask = shape(Color.WHITE, cornerRadius);
                } else if (base.getConstantState() != null) {
                    // SDK 标准按钮沿用原背景轮廓，避免把其圆角矩形水波画成方角。
                    mask = base.getConstantState().newDrawable(view.getResources()).mutate();
                    mask.setTint(Color.WHITE);
                } else {
                    mask = new ColorDrawable(Color.WHITE);
                }
                // 原生 Ripple 的扩散时序由系统管理；duration 控制下方状态缩放，不伪造触摸。
                view.setBackground(new ButtonRippleDrawable(base, mask, overlay));
            }
            float pressed = scale == null ? 1f : scale;
            StateListAnimator states = new StateListAnimator();
            states.addState(DISABLED, scaleAnimation(view, 1f, 0));
            states.addState(PRESSED, scaleAnimation(view, pressed, duration));
            states.addState(NORMAL, scaleAnimation(view, 1f, duration));
            view.setStateListAnimator(states);
        }
    }

    /** 原生状态动画从当前值开始，拖出、取消、释放均由 View 的 pressed 状态自动恢复。 */
    private static Animator scaleAnimation(View view, float scale, int duration) {
        AnimatorSet animation = new AnimatorSet();
        animation.playTogether(ObjectAnimator.ofFloat(view, View.SCALE_X, scale),
                ObjectAnimator.ofFloat(view, View.SCALE_Y, scale));
        animation.setDuration(duration);
        animation.setInterpolator(new LinearInterpolator());
        return animation;
    }

    /** 标记本插件的水波包装，重复主题应用时取回原背景，ARGB 只交给状态层一次。 */
    private static final class ButtonRippleDrawable extends RippleDrawable {
        final Drawable base;

        ButtonRippleDrawable(Drawable base, Drawable mask, int color) {
            super(new ColorStateList(new int[][]{HOVERED, NORMAL},
                    new int[]{hoverColor(color), color}), base, mask);
            this.base = base;
        }
    }

    private static int hoverColor(int color) {
        return (Math.round(Color.alpha(color) * 0.8f) << 24) | (color & 0x00ffffff);
    }

    private static GradientDrawable shape(int color, float radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(radius);
        return drawable;
    }

    private static float number(Map config, String key, float fallback) {
        Number value = (Number) config.get(key);
        return value == null ? fallback : value.floatValue();
    }

    private static int color(Map config, String key, int fallback) {
        String value = (String) config.get(key);
        return value == null ? fallback : Color.parseColor(value);
    }


    /**
     * 卡片本体仍占配置 frame；额外 inset 仅容纳阴影，不抬高 Z、不更改标准控件位置。
     * 负 spread 先收缩阴影轮廓再模糊，填充与边框分别使用自身 ARGB，不修改整个 View alpha。
     */
    private static final class CardSurfaceDrawable extends Drawable {
        final int inset;
        private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint shadow = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF body = new RectF();
        private final RectF shadowBounds = new RectF();
        private final RectF strokeBounds = new RectF();
        private final float radius;
        private final float spread;
        private final float offsetX;
        private final float offsetY;
        private final float borderWidth;
        private final int fillAlpha;
        private final int borderAlpha;
        private final int shadowAlpha;

        CardSurfaceDrawable(Map config, float density, int fillColor, int borderColor,
                            float borderWidth, float radius) {
            this.radius = radius;
            this.borderWidth = borderWidth;
            spread = number(config, "shadowSpreadRadius", 0f) * density;
            float blur = number(config, "shadowBlurRadius", 0f) * density;
            List<Number> offset = (List<Number>) config.get("shadowOffset");
            offsetX = offset == null ? 0f : offset.get(0).floatValue() * density;
            offsetY = offset == null ? 0f : offset.get(1).floatValue() * density;
            // 两倍 blur 覆盖原生高斯模糊尾部；对称外延使原来的水平居中规则仍对齐本体。
            inset = (int) Math.ceil(Math.max(0f, 2f * blur + spread
                    + Math.max(Math.abs(offsetX), Math.abs(offsetY))));
            fill.setColor(fillColor);
            stroke.setColor(borderColor);
            stroke.setStyle(Paint.Style.STROKE);
            stroke.setStrokeWidth(borderWidth);
            shadow.setColor(Color.parseColor((String) config.get("shadowColor")));
            fillAlpha = Color.alpha(fillColor);
            borderAlpha = Color.alpha(borderColor);
            shadowAlpha = Color.alpha(shadow.getColor());
            if (blur > 0f) shadow.setMaskFilter(new BlurMaskFilter(blur, BlurMaskFilter.Blur.NORMAL));
        }

        @Override
        protected void onBoundsChange(android.graphics.Rect bounds) {
            body.set(bounds.left + inset, bounds.top + inset, bounds.right - inset, bounds.bottom - inset);
            shadowBounds.set(body.left - spread + offsetX, body.top - spread + offsetY,
                    body.right + spread + offsetX, body.bottom + spread + offsetY);
            strokeBounds.set(body);
            strokeBounds.inset(borderWidth / 2f, borderWidth / 2f);
        }

        @Override
        public void draw(Canvas canvas) {
            if (!shadowBounds.isEmpty()) {
                float shadowRadius = Math.max(0f, radius + spread);
                canvas.drawRoundRect(shadowBounds, shadowRadius, shadowRadius, shadow);
            }
            canvas.drawRoundRect(body, radius, radius, fill);
            if (borderWidth > 0f) {
                float strokeRadius = Math.max(0f, radius - borderWidth / 2f);
                canvas.drawRoundRect(strokeBounds, strokeRadius, strokeRadius, stroke);
            }
        }

        @Override
        public void setAlpha(int alpha) {
            // 本体、边框与阴影的透明度来自各自颜色；外部 Drawable alpha 只作为统一调制。
            fill.setAlpha(alpha * fillAlpha / 255);
            stroke.setAlpha(alpha * borderAlpha / 255);
            shadow.setAlpha(alpha * shadowAlpha / 255);
            invalidateSelf();
        }

        @Override
        public void setColorFilter(ColorFilter filter) {
            fill.setColorFilter(filter);
            stroke.setColorFilter(filter);
            shadow.setColorFilter(filter);
            invalidateSelf();
        }

        @Override
        public int getOpacity() {
            return PixelFormat.TRANSLUCENT;
        }
    }
}
