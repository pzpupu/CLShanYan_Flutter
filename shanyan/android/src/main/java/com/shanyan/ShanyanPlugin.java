package com.shanyan;

import android.app.Activity;
import android.content.Context;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.text.TextUtils;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.chuanglan.shanyan_sdk.OneKeyLoginManager;
import com.chuanglan.shanyan_sdk.listener.ActionListener;
import com.chuanglan.shanyan_sdk.listener.AuthenticationExecuteListener;
import com.chuanglan.shanyan_sdk.listener.GetPhoneInfoListener;
import com.chuanglan.shanyan_sdk.listener.InitListener;
import com.chuanglan.shanyan_sdk.listener.LoginActivityStatusListener;
import com.chuanglan.shanyan_sdk.listener.OneKeyLoginListener;
import com.chuanglan.shanyan_sdk.listener.OpenLoginAuthListener;
import com.chuanglan.shanyan_sdk.listener.PricacyOnClickListener;
import com.chuanglan.shanyan_sdk.listener.ShanYanCustomInterface;
import com.chuanglan.shanyan_sdk.tool.ConfigPrivacyBean;
import com.chuanglan.shanyan_sdk.tool.ShanYanUIConfig;

import org.json.JSONException;
import org.json.JSONObject;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * MyFlutterPlugin
 */
public class ShanyanPlugin implements FlutterPlugin, MethodCallHandler {

    // 定义日志 TAG
    private static final String TAG = "|ProcessShanYanLogger_|";
    final String shanyan_code = "code";//返回码
    final String shanyan_message = "message";//描述
    String shanyan_innerCode = "innerCode"; //内层返回码
    String shanyan_innerDesc = "innerDesc"; //内层事件描述
    String shanyan_token = "token"; //token
    final String shanyan_type = "type";
    final String shanyan_result = "result";
    final String shanyan_operator = "operator";
    final String shanyan_widgetId = "widgetId";
    private MethodChannel channel;
    /**
     * Plugin registration.
     */
    private Context context;
    private boolean isFinish;
    // 仅记录本插件是否安装了扩展样式监听器，不持有授权 Activity 或其原生控件。
    private boolean nativeAuthStyleListenerInstalled;
    // Toast只属于当前请求；SDK Activity销毁或引擎卸载时撤销，不等待用户确认。
    private String activeRequestId;
    private Toast authErrorToast;
    private View authErrorOwnerView;
    private View.OnAttachStateChangeListener authErrorDetachListener;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "shanyan");
        context = flutterPluginBinding.getApplicationContext();
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        activeRequestId = null;
        clearAuthError();
        clearNativeAuthStyleListener();
    }

    @Override
    public void onMethodCall(MethodCall call, final Result result) {
        if (call.method.equals("setDebugMode")) {
            //闪验SDK 设置debug模式
            setDebug(call);
            result.success(null);
        }
        if (call.method.equals("setInitDebug")) {
            //闪验SDK 设置debug模式
            setInitDebug(call);
            result.success(null);
        }
        if (call.method.equals("getOperatorType")) {
            //闪验SDK 获取运营商类型
            getOperatorType(call, result);
        }
        if (call.method.equals("getOperatorInfo")) {
            //闪验SDK 获取运营商类型
            getOperatorInfo(call, result);
        }
        if (call.method.equals("init")) {
            //闪验SDK 初始化
            init(call, result);
        }
        if (call.method.equals("getPhoneInfo")) {
            //闪验SDK 预取号
            getPhoneInfo(result);
        }
        if (call.method.equals("setAuthThemeConfig")) {
            setAuthThemeConfig(call, result);
            result.success(null);
        }
        if (call.method.equals("openLoginAuth")) {
            //闪验SDK 拉起授权页
            openLoginAuth(call, result);
        }
        if (call.method.equals("finishAuthActivity")) {
            activeRequestId = null;
            clearAuthError();
            OneKeyLoginManager.getInstance().finishAuthActivity();
            // 回执只表示已执行关闭调用，不代表运营商网络请求已经取消。
            result.success(null);
        }
        if (call.method.equals("getPreIntStatus")) {
            result.success(OneKeyLoginManager.getInstance().getPreIntStatus());
        }
        if (call.method.equals("startAuthentication")) {
            startAuthentication(call, result);
        }
        if (call.method.equals("setLoadingVisibility")) {
            setLoadingVisibility(call, result);
        }
        if (call.method.equals("showAuthError")) {
            showAuthError(call, result);
        }
        if (call.method.equals("setCheckBoxValue")) {
            setCheckBoxValue(call);
        }
        if (call.method.equals("setActionListener")) {
            setActionListener(call, result);
        }
        if (call.method.equals("setPrivacyOnClickListener")) {
            setPrivacyOnClickListener(call, result);
        }
        if (call.method.equals("getOaidEnable")) {
            getOaidEnable(call);
            result.success(null);
        }
        if (call.method.equals("getSinbEnable")) {
            getSinbEnable(call);
            result.success(null);
        }
        if (call.method.equals("getSiEnable")) {
            getSiEnable(call);
            result.success(null);
        }
        if (call.method.equals("getIEnable")) {
            getIEnable(call);
            result.success(null);
        }
        if (call.method.equals("getMaEnable")) {
            getMaEnable(call);
            result.success(null);
        }
        if (call.method.equals("getImEnable")) {
            getImEnable(call);
            result.success(null);
        }
        if (call.method.equals("clearScripCache")) {
            OneKeyLoginManager.getInstance().clearScripCache(context);
            result.success(null);
        }
        if (call.method.equals("setTimeOutForPreLogin")) {
            int timeOut = call.argument("timeOut");
            OneKeyLoginManager.getInstance().setTimeOutForPreLogin(timeOut);
            result.success(null);
        }
        if (call.method.equals("performLoginClick")) {
            OneKeyLoginManager.getInstance().performLoginClick();
        }
        if (call.method.equals("getPrivacyCheckBox")) {
            getPrivacyCheckBox(call, result);
        }
        if (call.method.equals("setActivityLifecycleCallbacksEnable")) {
            boolean enable = call.argument("activityLifecycleCallbacksEnable");
            OneKeyLoginManager.getInstance().setActivityLifecycleCallbacksEnable(enable);
        }
        if (call.method.equals("checkProcessesEnable")) {
            boolean enable = call.argument("checkProcessesEnable");
            OneKeyLoginManager.getInstance().checkProcessesEnable(enable);
        }
        if (call.method.equals("removeAllListener")) {
            OneKeyLoginManager.getInstance().removeAllListener();
            // SDK 的 removeAllListener 不清理 LoginActivityStatusListener，扩展监听需显式注销。
            clearNativeAuthStyleListener();
            result.success(null);
        }
    }

    private void setPrivacyOnClickListener(MethodCall call, Result result) {
        OneKeyLoginManager.getInstance().setPrivacyOnClickListener(new PricacyOnClickListener() {
            @Override
            public void onClick(String s, String s1) {
                Map<String, Object> map = new HashMap<>();
                map.put("url", s);
                map.put("name", s1);
                Log.e(TAG, "map=" + map);
                channel.invokeMethod("onReceivePrivacyEvent", map);
            }
        });
    }

    private void getPrivacyCheckBox(MethodCall call, Result result) {
        CheckBox privacyCheckBox = OneKeyLoginManager.getInstance().getPrivacyCheckBox();
        result.success(privacyCheckBox);
    }

    private void getImEnable(MethodCall call) {
        boolean imEnable = call.argument("imEnable");
        OneKeyLoginManager.getInstance().getImEnable(imEnable);
    }

    private void getMaEnable(MethodCall call) {
        boolean maEnable = call.argument("maEnable");
        OneKeyLoginManager.getInstance().getMaEnable(maEnable);
    }

    private void getIEnable(MethodCall call) {
        boolean iEnable = call.argument("iEnable");
        OneKeyLoginManager.getInstance().getIEnable(iEnable);
    }

    private void getSiEnable(MethodCall call) {
        boolean sibEnable = call.argument("sibEnable");
        OneKeyLoginManager.getInstance().getSiEnable(sibEnable);
    }

    private void getSinbEnable(MethodCall call) {
        boolean sinbEnable = call.argument("sinbEnable");
        OneKeyLoginManager.getInstance().getSinbEnable(sinbEnable);
    }

    private void getOaidEnable(MethodCall call) {
        boolean oaidEnable = call.argument("oaidEnable");
        OneKeyLoginManager.getInstance().getOaidEnable(oaidEnable);
    }

    private void getOperatorType(MethodCall call, Result result) {
        String operatorType = OneKeyLoginManager.getInstance().getOperatorType(context);
        result.success(operatorType);
    }

    private void getOperatorInfo(MethodCall call, Result result) {
        String operatorInfo = OneKeyLoginManager.getInstance().getOperatorInfo(context);
        result.success(operatorInfo);
    }

    private void setActionListener(MethodCall call, Result result) {
        OneKeyLoginManager.getInstance().setActionListener(new ActionListener() {
            @Override
            public void ActionListner(int i, int i1, String s) {
                Map<String, Object> map = new HashMap<>();
                map.put(shanyan_type, i);
                map.put(shanyan_code, i1);
                map.put(shanyan_message, s);
                Log.e(TAG, "map=" + map.toString());
                channel.invokeMethod("onReceiveAuthEvent", map);
            }
        });
    }

    private void setCheckBoxValue(MethodCall call) {
        boolean isChecked = call.argument("isChecked");
        OneKeyLoginManager.getInstance().setCheckBoxValue(isChecked);
    }

    /** 仅允许当前授权页接收反馈命令；不回退到 Flutter Activity。 */
    private Activity authActivityForCall(MethodCall call, Result result) {
        String requestId = call.argument("requestId");
        Activity activity = OneKeyLoginManager.getInstance().getAuthActivity();
        if (requestId == null || !requestId.equals(activeRequestId)
                || activity == null || activity.isFinishing() || activity.isDestroyed()) {
            result.error("auth_page_unavailable", "授权页已关闭或请求已失效", null);
            return null;
        }
        return activity;
    }

    /** 通过 SDK 公开方法立即修改 loading，不排队查找另一轮页面。 */
    private void setLoadingVisibility(MethodCall call, Result result) {
        if (authActivityForCall(call, result) == null) {
            return;
        }
        boolean visibility = call.argument("visibility");
        OneKeyLoginManager.getInstance().setLoadingVisibility(visibility);
        result.success(null);
    }

    /** 使用系统非阻塞Toast，提交展示后立即回执；提示仍可见时允许用户再次点击。 */
    private void showAuthError(MethodCall call, Result result) {
        Activity activity = authActivityForCall(call, result);
        if (activity == null) {
            return;
        }
        // 替换旧消息而非排队；应用Context避免Toast持有已关闭的授权Activity。
        clearAuthError();
        String message = call.argument("message");
        final Toast toast = Toast.makeText(context, message, Toast.LENGTH_LONG);
        authErrorToast = toast;
        authErrorOwnerView = activity.getWindow().getDecorView();
        authErrorDetachListener = new View.OnAttachStateChangeListener() {
            @Override
            public void onViewAttachedToWindow(View view) {
                // 只观察当前授权页销毁，不接管 SDK 的创建与布局。
            }

            @Override
            public void onViewDetachedFromWindow(View view) {
                if (authErrorToast == toast) {
                    clearAuthError();
                }
            }
        };
        authErrorOwnerView.addOnAttachStateChangeListener(authErrorDetachListener);
        toast.show();
        result.success(null);
    }

    /** 关闭页面或替换消息时撤销Toast及页面监听，不保留模态提示或挂起回执。 */
    private void clearAuthError() {
        Toast toast = authErrorToast;
        authErrorToast = null;
        if (authErrorOwnerView != null && authErrorDetachListener != null) {
            authErrorOwnerView.removeOnAttachStateChangeListener(authErrorDetachListener);
        }
        authErrorOwnerView = null;
        authErrorDetachListener = null;
        if (toast != null) {
            toast.cancel();
        }
    }

    private void startAuthentication(MethodCall call, final Result result) {
        OneKeyLoginManager.getInstance().startAuthentication(new AuthenticationExecuteListener() {
            @Override
            public void authenticationRespond(int code, String msg) {
                Map<String, Object> map = new HashMap<>();
                try {
                    JSONObject jsonObject = new JSONObject(msg);
                    if (2000 == code) {
                        code = 1000;
                        map.put(shanyan_token, jsonObject.optString("token"));
                        map.put(shanyan_innerCode, code);
                        map.put(shanyan_innerDesc, "获取token成功");
                        map.put(shanyan_message, "token success");
                    } else {
                        map.put(shanyan_innerCode, jsonObject.optInt("innerCode"));
                        map.put(shanyan_innerDesc, jsonObject.optString("innerDesc"));
                        map.put(shanyan_message, jsonObject.optString("message"));
                    }
                    map.put(shanyan_code, code);
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                result.success(map);
            }
        });
    }

    private void openLoginAuth(MethodCall call, final Result result) {
        // 捕获发起页面时的编号，异步结果不得借用后来页面的编号。
        final String requestId = call.argument("requestId");
        activeRequestId = requestId;
        clearAuthError();
        //闪验SDK 拉起授权页
        OneKeyLoginManager.getInstance().openLoginAuth(isFinish, new OpenLoginAuthListener() {
            @Override
            public void getOpenLoginAuthStatus(int code, String msg) {
                //授权页是否拉起成功回调
                Map<String, Object> map = new HashMap<>();
                map.put(shanyan_code, code);
                map.put(shanyan_message, msg);
                try {
                    JSONObject jsonObject = new JSONObject(msg);
                    map.put(shanyan_innerCode, jsonObject.optInt("innerCode"));
                    map.put(shanyan_innerDesc, jsonObject.optString("innerDesc"));
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                result.success(map);
            }
        }, new OneKeyLoginListener() {
            @Override
            public void getOneKeyLoginStatus(int code, String msg) {
                // 返回事件只清理其所属页面，旧回调不能影响新页面反馈。
                if (code == 1011 && requestId != null && requestId.equals(activeRequestId)) {
                    activeRequestId = null;
                    clearAuthError();
                }
                //点击授权页“一键登录”按钮或者返回键（包括物理返回键）回调
                Map<String, Object> map = new HashMap<>();
                map.put("requestId", requestId);
                map.put(shanyan_code, code);
                try {
                    JSONObject jsonObject = new JSONObject(msg);
                    if (1000 == code) {
                        map.put(shanyan_token, jsonObject.optString("token"));
                        map.put(shanyan_innerCode, code);
                        map.put(shanyan_innerDesc, "获取token成功");
                        map.put(shanyan_message, "token success");
                    } else {
                        map.put(shanyan_innerCode, jsonObject.optInt("innerCode"));
                        map.put(shanyan_innerDesc, jsonObject.optString("innerDesc"));
                        map.put(shanyan_message, jsonObject.optString("message"));
                    }
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                channel.invokeMethod("onReceiveAuthPageEvent", map);
            }
        });
    }

    private void getPhoneInfo(final Result result) {
        OneKeyLoginManager.getInstance().getPhoneInfo(new GetPhoneInfoListener() {
            @Override
            public void getPhoneInfoStatus(int code, String msg) {
                Map<String, Object> map = new HashMap<>();
                if (1022 == code) {
                    map.put(shanyan_code, 1000);
                } else {
                    map.put(shanyan_code, code);
                }

                try {
                    JSONObject jsonObject = new JSONObject(msg);
                    map.put(shanyan_innerCode, jsonObject.optInt("innerCode"));
                    map.put(shanyan_innerDesc, jsonObject.optString("innerDesc"));
                    map.put(shanyan_message, jsonObject.optString("message"));
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                result.success(map);
            }
        });
    }

    private void init(MethodCall call, final Result result) {
        String appId = call.argument("appId");
        OneKeyLoginManager.getInstance().init(context, appId, new InitListener() {
            @Override
            public void getInitStatus(int code, String msg) {
                Map<String, Object> map = new HashMap<>();
                if (1022 == code) {
                    map.put(shanyan_code, 1000);
                } else {
                    map.put(shanyan_code, code);
                }
                try {
                    JSONObject jsonObject = new JSONObject(msg);
                    map.put(shanyan_innerCode, jsonObject.optInt("innerCode"));
                    map.put(shanyan_innerDesc, jsonObject.optString("innerDesc"));
                    map.put(shanyan_message, jsonObject.optString("message"));
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                result.success(map);
            }
        });
    }

    private void setDebug(MethodCall call) {
        boolean debug = call.argument("debug");
        OneKeyLoginManager.getInstance().setDebug(debug);
    }

    private void setInitDebug(MethodCall call) {
        boolean debug = call.argument("initDebug");
        OneKeyLoginManager.getInstance().setInitDebug(debug);
    }

    private void setAuthThemeConfig(MethodCall call, Result result) {
        //竖屏设置
        Map portraitConfig = call.argument("androidPortrait");
        List<Map> portraitWidgets = (List<Map>) valueForKey(portraitConfig, "widgets");
        List<Map> portraitWidgetLayout = (List<Map>) valueForKey(portraitConfig, "widgetLayouts");
        List<Map> morePrivacy = (List<Map>) valueForKey(portraitConfig, "morePrivacy");
        ShanYanUIConfig.Builder builder = new ShanYanUIConfig.Builder();
        if (null != morePrivacy) {
            setMorePrivacy(morePrivacy, builder);
        }
        if (null != portraitConfig) {
            setAuthLayoutView(portraitConfig, builder);
        }
        addCustomWidgets(portraitWidgets, builder, false);
        if (null != portraitWidgetLayout) {
            for (Map widgetMap : portraitWidgetLayout) {
                /// 新增自定义的控件
                String type = (String) widgetMap.get("type");
                if (type.equals("RelativeLayout")) {
                    addCustomRelativeLayoutWidgets(widgetMap, builder);
                } else {
                    Log.e(TAG, "don't support widgetlayout");
                }
            }
        }
        // 官方 SDK 将自定义控件插入 body 的索引 0，最后注册背景才能位于所有内容下方。
        addCustomWidgets(portraitWidgets, builder, true);

        //横屏设置
        Map landscapeConfig = call.argument("androidLandscape");
        List<Map> landscapeWidgets = (List<Map>) valueForKey(landscapeConfig, "widgets");
        List<Map> landscapeWidgetLayout = (List<Map>) valueForKey(landscapeConfig, "widgetLayouts");
        ShanYanUIConfig.Builder landscapeBuilder = new ShanYanUIConfig.Builder();
        if (null != landscapeConfig) {
            setAuthLayoutView(landscapeConfig, landscapeBuilder);
        }
        addCustomWidgets(landscapeWidgets, landscapeBuilder, false);
        if (null != landscapeWidgetLayout) {
            for (Map widgetMap : landscapeWidgetLayout) {
                /// 新增自定义的控件
                String type = (String) widgetMap.get("type");
                if (type.equals("RelativeLayout")) {
                    addCustomRelativeLayoutWidgets(widgetMap, landscapeBuilder);
                } else {
                    Log.e(TAG, "don't support widgetlayout");
                }
            }
        }
        addCustomWidgets(landscapeWidgets, landscapeBuilder, true);
        ShanYanUIConfig portraitUIConfig = builder.build();
        ShanYanUIConfig landscapeUIConfig;
        if (null != landscapeBuilder) {
            landscapeUIConfig = landscapeBuilder.build();
        } else {
            landscapeUIConfig = null;
        }
        OneKeyLoginManager.getInstance().setAuthThemeConfig(portraitUIConfig, landscapeUIConfig);
        installNativeAuthStyleListener(portraitConfig, landscapeConfig);
    }


    /**
     * 通过 SDK 公开生命周期在其真实控件完成初始化后补充样式。
     * 每次主题调用替换不可变配置快照；不异步投递任务，也不复用上一页的控件。
     */
    private void installNativeAuthStyleListener(Map portraitConfig, Map landscapeConfig) {
        final NativeAuthViewStyle portrait = new NativeAuthViewStyle(portraitConfig);
        final NativeAuthViewStyle landscape = new NativeAuthViewStyle(landscapeConfig);
        if (!portrait.hasChanges() && !landscape.hasChanges()) {
            clearNativeAuthStyleListener();
            return;
        }
        OneKeyLoginManager.getInstance().setLoginActivityStatusListener(
                new NativeAuthStyleListener(portrait, landscape));
        nativeAuthStyleListenerInstalled = true;
    }

    /**
     * 主题移除扩展字段或 Flutter 引擎卸载时注销本插件安装的监听器。
     * 未使用扩展样式的消费者不会被额外注册或清除 SDK 生命周期监听器。
     */
    private void clearNativeAuthStyleListener() {
        if (nativeAuthStyleListenerInstalled) {
            OneKeyLoginManager.getInstance().setLoginActivityStatusListener(null);
            nativeAuthStyleListenerInstalled = false;
        }
    }

    /**
     * SDK 单例只保留无宿主引用的配置；协议页返回不会重新追加说明。
     * SDK 在 onActivityCreated 前已完成真实说明赋值、按钮样式和点击监听器绑定。
     */
    private static final class NativeAuthStyleListener implements LoginActivityStatusListener {
        private final NativeAuthViewStyle portrait;
        private final NativeAuthViewStyle landscape;

        private NativeAuthStyleListener(NativeAuthViewStyle portrait,
                                        NativeAuthViewStyle landscape) {
            this.portrait = portrait;
            this.landscape = landscape;
        }

        @Override
        public void onActivityCreated(Activity activity) {
            if (activity.isFinishing()) {
                return;
            }
            NativeAuthViewStyle style = activity.getResources().getConfiguration().orientation
                    == Configuration.ORIENTATION_LANDSCAPE ? landscape : portrait;
            style.apply(activity);
        }

        @Override
        public void onActivityDestroyed(Activity activity) {
            // 没有 Activity、View 或排队任务需要释放；旧页面销毁不能清掉新主题监听器。
        }
    }

    /**
     * 只保存本次主题显式提供的扩展值，空值保留 SDK 默认外观。
     * 高度和宽度按 dp 换算，文本字号仍完全由 SDK 的 SP 配置管理。
     */
    private static final class NativeAuthViewStyle {
        private final Float elevation;
        private final Integer shadowColor;
        private final String sloganSuffix;
        private final Integer sloganWidth;
        private final ShanyanViewStyle.ButtonInteraction interaction;

        private NativeAuthViewStyle(Map config) {
            Number elevationValue = config == null ? null
                    : (Number) config.get("setLogBtnElevation");
            elevation = elevationValue == null ? null : elevationValue.floatValue();
            String colorValue = config == null ? null
                    : (String) config.get("setLogBtnShadowColor");
            shadowColor = colorValue == null ? null : Color.parseColor(colorValue);
            sloganSuffix = config == null ? null : (String) config.get("setSloganTextSuffix");
            Number widthValue = config == null ? null : (Number) config.get("setSloganWidth");
            sloganWidth = widthValue == null ? null : widthValue.intValue();
            interaction = new ShanyanViewStyle.ButtonInteraction(config, true);
        }

        private boolean hasChanges() {
            return elevation != null || shadowColor != null
                    || !TextUtils.isEmpty(sloganSuffix) || sloganWidth != null || interaction.hasChanges();
        }

        /** 仅按 SDK 公开资源 ID 修改目标控件，不更改宿主或 SDK 根视图层级。 */
        private void apply(Activity activity) {
            float density = activity.getResources().getDisplayMetrics().density;
            View button = activity.findViewById(R.id.shanyan_view_bt_one_key_login);
            if (button != null) {
                if (elevation != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    // 先确定静态 Z；后面的状态样式只控制缩放，不接管 SDK 点击事件。
                    button.setStateListAnimator(null);
                    button.setTranslationZ(0f);
                    button.setElevation(Math.max(0f, elevation) * density);
                }
                if (shadowColor != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    // ARGB 原样交给原生阴影，绝不再对按钮或 outline 乘一次 alpha。
                    button.setOutlineAmbientShadowColor(shadowColor);
                    button.setOutlineSpotShadowColor(shadowColor);
                }
                // API 21–27（含 APP 支持的 26–27）只能使用系统 elevation 阴影色；
                // 不以软件假按钮、私有 API 或提高 minSdk 模拟 API 28 的颜色能力。
                interaction.apply(button, null);
            }
            if (TextUtils.isEmpty(sloganSuffix) && sloganWidth == null) {
                return;
            }
            View sloganView = activity.findViewById(R.id.shanyan_view_identify_tv);
            if (!(sloganView instanceof TextView)) {
                return;
            }
            TextView slogan = (TextView) sloganView;
            CharSequence original = slogan.getText();
            if (!TextUtils.isEmpty(sloganSuffix) && !TextUtils.isEmpty(original)
                    && (original.length() < sloganSuffix.length()
                    || !TextUtils.regionMatches(original,
                    original.length() - sloganSuffix.length(),
                    sloganSuffix, 0, sloganSuffix.length()))) {
                // 保留 SDK 根据真实运营商生成的原文和 span；重复生命周期最多追加一次。
                slogan.setText(TextUtils.concat(original, sloganSuffix));
            }
            // 只放开真实说明的自然换行，不缩字、不省略、不强制改变既有位置规则。
            slogan.setSingleLine(false);
            slogan.setMaxLines(Integer.MAX_VALUE);
            slogan.setEllipsize(null);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                slogan.setAutoSizeTextTypeWithDefaults(TextView.AUTO_SIZE_TEXT_TYPE_NONE);
            }
            if (sloganWidth != null && sloganWidth > 0) {
                slogan.setMaxWidth(Math.round(sloganWidth * density));
            }
            ViewGroup.LayoutParams params = slogan.getLayoutParams();
            params.width = ViewGroup.LayoutParams.WRAP_CONTENT;
            params.height = ViewGroup.LayoutParams.WRAP_CONTENT;
            slogan.setLayoutParams(params);
        }
    }

    /**
     * 分别注册普通控件和装饰背景，不修改 SDK 自身的视图层级。
     * 背景反向注册，使配置列表中靠后的背景在视觉上覆盖靠前的背景。
     */
    private void addCustomWidgets(List<Map> widgets, ShanYanUIConfig.Builder builder,
                                 boolean backgrounds) {
        if (widgets == null) {
            return;
        }
        for (int offset = 0; offset < widgets.size(); offset++) {
            int index = backgrounds ? widgets.size() - offset - 1 : offset;
            Map widget = widgets.get(index);
            if (Boolean.TRUE.equals(widget.get("isBackground")) != backgrounds) {
                continue;
            }
            String type = (String) widget.get("type");
            if ("TextView".equals(type)) {
                addCustomTextWidgets(widget, builder);
            } else if ("Button".equals(type)) {
                addCustomBtnWidgets(widget, builder);
            } else {
                Log.e(TAG, "don't support widget");
            }
        }
    }

    /**
     * 将公开配置应用到原生文本控件，并保留普通控件原有的点击和关闭行为。
     * addCustomView 的第三个参数选择导航区域；false 始终表示授权页 body，
     * 其背景由外层布局绘制，因此索引 0 的装饰仍在页面背景图上方。
     */
    private void registerCustomWidget(Map para, TextView customView,
                                      ShanYanUIConfig.Builder builder) {
        ShanyanViewStyle.applyCustomWidget(customView, para);
        Boolean textBold = (Boolean) para.get("textBold");
        if (textBold != null) {
            // 保留控件字体家族，显式 false 恢复常规字重；null 不覆盖原生默认字重。
            customView.setTypeface(customView.getTypeface(), textBold ? Typeface.BOLD : Typeface.NORMAL);
        }
        Number numberOfLines = (Number) para.get("numberOfLines");
        if (numberOfLines != null) {
            int lines = numberOfLines.intValue();
            customView.setSingleLine(lines == 1);
            customView.setMaxLines(lines == 0 ? Integer.MAX_VALUE : lines);
        }
        if (Boolean.TRUE.equals(para.get("isBackground"))) {
            customView.setFocusable(false);
            customView.setFocusableInTouchMode(false);
            customView.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
            builder.addCustomView(customView, false, false, null);
            return;
        }
        boolean isFinish = (Boolean) para.get("isFinish");
        final HashMap jsonMap = new HashMap();
        jsonMap.put(shanyan_widgetId, para.get("widgetId"));
        builder.addCustomView(customView, isFinish, false, new ShanYanCustomInterface() {
            @Override
            public void onClick(Context context, View view) {
                channel.invokeMethod("onReceiveClickWidgetEvent", jsonMap);
            }
        });
    }

    private void setMorePrivacy(List<Map> morePrivacy, ShanYanUIConfig.Builder builder) {
        List<ConfigPrivacyBean> list = new ArrayList();
        for (Map privacy : morePrivacy) {
            String name = (String) privacy.get("name");
            String url = (String) privacy.get("url");
            String color = (String) privacy.get("color");
            String midStr = (String) privacy.get("midStr");
            String title = (String) privacy.get("title");
            ConfigPrivacyBean bean = new ConfigPrivacyBean(name, url);
            if (!TextUtils.isEmpty(color)) {
                bean.setColor(Color.parseColor(color));
            }
            if (!TextUtils.isEmpty(midStr)) {
                bean.setMidStr(midStr);
            }
            if (!TextUtils.isEmpty(title)) {
                bean.setTitle(title);
            }
            list.add(bean);
        }
        builder.setMorePrivacy(list);
    }

    /**
     * 添加自定义xml布局文件
     */
    private void addCustomRelativeLayoutWidgets(Map para, ShanYanUIConfig.Builder builder) {
        Log.d(TAG, "addCustomRelativeLayoutWidgets: para = " + para);
        String widgetLayoutName = (String) para.get("widgetLayoutName");
        Object widgetId = para.get("widgetLayoutId");
        int left = (Integer) para.get("left");
        int top = (Integer) para.get("top");
        int right = (Integer) para.get("right");
        int bottom = (Integer) para.get("bottom");
        int width = (Integer) para.get("width");
        int height = (Integer) para.get("height");
        LayoutInflater inflater1 = LayoutInflater.from(context);
        if (0 != getLayoutForId(widgetLayoutName)) {
            RelativeLayout relativeLayout = (RelativeLayout) inflater1.inflate(getLayoutForId(widgetLayoutName), null);
            RelativeLayout.LayoutParams mLayoutParams1 = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.WRAP_CONTENT, RelativeLayout.LayoutParams.WRAP_CONTENT);
            mLayoutParams1.addRule(RelativeLayout.CENTER_HORIZONTAL);
            if (left > 0) {
                mLayoutParams1.leftMargin = dp2Pix(context, (float) left);
                mLayoutParams1.addRule(RelativeLayout.ALIGN_PARENT_LEFT);
            }
            if (top > 0) {
                mLayoutParams1.topMargin = dp2Pix(context, (float) top);
            }
            if (right > 0) {
                mLayoutParams1.rightMargin = dp2Pix(context, (float) right);
                mLayoutParams1.addRule(RelativeLayout.ALIGN_PARENT_RIGHT);
            }
            if (bottom > 0) {
                mLayoutParams1.bottomMargin = dp2Pix(context, (float) bottom);
                mLayoutParams1.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
            }
            if (width > 0) {
                mLayoutParams1.width = dp2Pix(context, (float) width);
            }
            if (height > 0) {
                mLayoutParams1.height = dp2Pix(context, (float) height);
            }
            if (null != relativeLayout) {
                relativeLayout.setLayoutParams(mLayoutParams1);
                //授权页 隐私协议栏
                if (null != widgetId) {
                    final ArrayList<String> widgetIdList = (ArrayList) widgetId;
                    if (null != widgetIdList && widgetIdList.size() > 0) {
                        for (int i = 0; i < widgetIdList.size(); i++) {
                            if (0 != (getId(widgetIdList.get(i)))) {
                                final int finalI = i;
                                relativeLayout.findViewById(getId(widgetIdList.get(i))).setOnClickListener(new View.OnClickListener() {
                                    @Override
                                    public void onClick(View v) {
                                        final Map<String, Object> jsonMap = new HashMap<>();
                                        jsonMap.put(shanyan_widgetId, widgetIdList.get(finalI));
                                        channel.invokeMethod("onReceiveClickWidgetEvent", jsonMap);
                                    }
                                });
                            }

                        }
                    }
                }
                builder.addCustomView(relativeLayout, false, false, null);
            }
        } else {
            Log.d(TAG, "layout【" + widgetLayoutName + "】 not found!");
        }
    }

    /**
     * 添加自定义 Button
     */
    private void addCustomBtnWidgets(Map para, ShanYanUIConfig.Builder builder) {
        Log.d(TAG, "addCustomBtnView " + para);
        int left = (Integer) para.get("left");
        int top = (Integer) para.get("top");
        int right = (Integer) para.get("right");
        int bottom = (Integer) para.get("bottom");
        int width = (Integer) para.get("width");
        int height = (Integer) para.get("height");
        String textContent = (String) para.get("textContent");
        Object font = para.get("textFont");
        Object textColor = para.get("textColor");
        Object backgroundColor = para.get("backgroundColor");
        Object backgroundImgPath = para.get("backgroundImgPath");
        Object alignmet = para.get("textAlignment");
        final boolean isBackground = Boolean.TRUE.equals(para.get("isBackground"));
        Button customView = new Button(context) {
            // SDK 会在挂载后统一绑定监听器，装饰控件拒绝该绑定以保持触摸穿透。
            @Override
            public void setOnClickListener(View.OnClickListener listener) {
                super.setOnClickListener(isBackground ? null : listener);
                if (isBackground) {
                    setClickable(false);
                }
            }
        };
        customView.setText(textContent);
        if (textColor != null) {
            customView.setTextColor(Color.parseColor((String) textColor));
        }
        if (font != null) {
            double titleFont = (double) font;
            if (titleFont > 0) {
                customView.setTextSize((float) titleFont);
            }
        }
        if (backgroundColor != null) {
            customView.setBackgroundColor(Color.parseColor((String) backgroundColor));
        }
        if (null != getDrawableByReflect(backgroundImgPath)) {
            customView.setBackground(getDrawableByReflect(backgroundImgPath));
        }
        if (alignmet != null) {
            String textAlignment = (String) alignmet;
            int gravity = getAlignmentFromString(textAlignment);
            customView.setGravity(gravity);
        }
        RelativeLayout.LayoutParams mLayoutParams1 = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.WRAP_CONTENT, RelativeLayout.LayoutParams.WRAP_CONTENT);
        mLayoutParams1.addRule(RelativeLayout.CENTER_HORIZONTAL);
        if (left > 0) {
            mLayoutParams1.leftMargin = dp2Pix(context, (float) left);
            mLayoutParams1.addRule(RelativeLayout.ALIGN_PARENT_LEFT);
        }
        if (top > 0) {
            mLayoutParams1.topMargin = dp2Pix(context, (float) top);
        }
        if (right > 0) {
            mLayoutParams1.rightMargin = dp2Pix(context, (float) right);
            mLayoutParams1.addRule(RelativeLayout.ALIGN_PARENT_RIGHT);
        }
        if (bottom > 0) {
            mLayoutParams1.bottomMargin = dp2Pix(context, (float) bottom);
            mLayoutParams1.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
        }
        if (width > 0) {
            mLayoutParams1.width = dp2Pix(context, (float) width);
        }
        if (height > 0) {
            mLayoutParams1.height = dp2Pix(context, (float) height);
        }
        customView.setLayoutParams(mLayoutParams1);
        registerCustomWidget(para, customView, builder);
    }

    /**
     * 添加自定义 TextView
     */
    private void addCustomTextWidgets(Map para, ShanYanUIConfig.Builder builder) {
        Log.d(TAG, "addCustomTextView " + para);
        int left = (Integer) para.get("left");
        int top = (Integer) para.get("top");
        int right = (Integer) para.get("right");
        int bottom = (Integer) para.get("bottom");
        int width = (Integer) para.get("width");
        int height = (Integer) para.get("height");
        String textContent = (String) para.get("textContent");
        Object font = para.get("textFont");
        Object textColor = para.get("textColor");
        Object backgroundColor = para.get("backgroundColor");
        Object backgroundImgPath = para.get("backgroundImgPath");
        Object alignmet = para.get("textAlignment");
        final boolean isBackground = Boolean.TRUE.equals(para.get("isBackground"));
        TextView customView = new TextView(context) {
            // 与装饰按钮一致，不让 SDK 的统一监听器把背景变成可点击区域。
            @Override
            public void setOnClickListener(View.OnClickListener listener) {
                super.setOnClickListener(isBackground ? null : listener);
                if (isBackground) {
                    setClickable(false);
                }
            }
        };
        customView.setText(textContent);
        if (textColor != null) {
            customView.setTextColor(Color.parseColor((String) textColor));
        }
        if (font != null) {
            double titleFont = (double) font;
            if (titleFont > 0) {
                customView.setTextSize((float) titleFont);
            }
        }
        if (backgroundColor != null) {
            customView.setBackgroundColor(Color.parseColor((String) backgroundColor));
        }
        if (null != getDrawableByReflect(backgroundImgPath)) {
            customView.setBackground(getDrawableByReflect(backgroundImgPath));
        }
        if (alignmet != null) {
            String textAlignment = (String) alignmet;
            int gravity = getAlignmentFromString(textAlignment);
            customView.setGravity(gravity);
        }
        RelativeLayout.LayoutParams mLayoutParams1 = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.WRAP_CONTENT, RelativeLayout.LayoutParams.WRAP_CONTENT);
        mLayoutParams1.addRule(RelativeLayout.CENTER_HORIZONTAL);
        if (left > 0) {
            mLayoutParams1.leftMargin = dp2Pix(context, (float) left);
            mLayoutParams1.addRule(RelativeLayout.ALIGN_PARENT_LEFT);
        }
        if (top > 0) {
            mLayoutParams1.topMargin = dp2Pix(context, (float) top);
        }
        if (right > 0) {
            mLayoutParams1.rightMargin = dp2Pix(context, (float) right);
            mLayoutParams1.addRule(RelativeLayout.ALIGN_PARENT_RIGHT);
        }
        if (bottom > 0) {
            mLayoutParams1.bottomMargin = dp2Pix(context, (float) bottom);
            mLayoutParams1.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
        }
        if (width > 0) {
            mLayoutParams1.width = dp2Pix(context, (float) width);
        }
        if (height > 0) {
            mLayoutParams1.height = dp2Pix(context, (float) height);
        }
        customView.setLayoutParams(mLayoutParams1);
        registerCustomWidget(para, customView, builder);
    }

    private void setAuthLayoutView(Map shanYanUIConfig, ShanYanUIConfig.Builder builder) {
        Log.d(TAG, "shanYanUIConfig " + shanYanUIConfig);
        Object isFinish = valueForKey(shanYanUIConfig, "isFinish");
        Object setAuthBGImgPath = valueForKey(shanYanUIConfig, "setAuthBGImgPath");
        Object setAuthBgGifPath = valueForKey(shanYanUIConfig, "setAuthBgGifPath");
        Object setAuthBgVideoPath = valueForKey(shanYanUIConfig, "setAuthBgVideoPath");

        Object setStatusBarColor = valueForKey(shanYanUIConfig, "setStatusBarColor");
        Object setLogBtnBackgroundColor = valueForKey(shanYanUIConfig, "setLogBtnBackgroundColor");
        Object setLightColor = valueForKey(shanYanUIConfig, "setLightColor");
        Object setStatusBarHidden = valueForKey(shanYanUIConfig, "setStatusBarHidden");
        Object setVirtualKeyTransparent = valueForKey(shanYanUIConfig, "setVirtualKeyTransparent");
        Object setAuthFlagSecureEnable = valueForKey(shanYanUIConfig, "setAuthFlagSecureEnable");
        Object setPrivacyFlagSecureEnable = valueForKey(shanYanUIConfig, "setPrivacyFlagSecureEnable");

        Object setFullScreen = valueForKey(shanYanUIConfig, "setFullScreen");
        Object setNavColor = valueForKey(shanYanUIConfig, "setNavColor");
        Object setNavText = valueForKey(shanYanUIConfig, "setNavText");
        Object setNavTextColor = valueForKey(shanYanUIConfig, "setNavTextColor");
        Object setNavTextSize = valueForKey(shanYanUIConfig, "setNavTextSize");
        Object setNavReturnImgPath = valueForKey(shanYanUIConfig, "setNavReturnImgPath");
        Object setNavReturnImgHidden = valueForKey(shanYanUIConfig, "setNavReturnImgHidden");
        Object setNavReturnBtnWidth = valueForKey(shanYanUIConfig, "setNavReturnBtnWidth");
        Object setNavReturnBtnHeight = valueForKey(shanYanUIConfig, "setNavReturnBtnHeight");
        Object setNavReturnBtnOffsetRightX = valueForKey(shanYanUIConfig, "setNavReturnBtnOffsetRightX");
        Object setNavReturnBtnOffsetX = valueForKey(shanYanUIConfig, "setNavReturnBtnOffsetX");
        Object setNavReturnBtnOffsetY = valueForKey(shanYanUIConfig, "setNavReturnBtnOffsetY");
        Object setAuthNavHidden = valueForKey(shanYanUIConfig, "setAuthNavHidden");
        Object setAuthNavTransparent = valueForKey(shanYanUIConfig, "setAuthNavTransparent");
        Object setNavTextBold = valueForKey(shanYanUIConfig, "setNavTextBold");
        Object setBackPressedAvailable = valueForKey(shanYanUIConfig, "setBackPressedAvailable");
        Object setFitsSystemWindows = valueForKey(shanYanUIConfig, "setFitsSystemWindows");


        Object setLogoImgPath = valueForKey(shanYanUIConfig, "setLogoImgPath");
        Object setLogoWidth = valueForKey(shanYanUIConfig, "setLogoWidth");
        Object setLogoHeight = valueForKey(shanYanUIConfig, "setLogoHeight");
        Object setLogoOffsetY = valueForKey(shanYanUIConfig, "setLogoOffsetY");
        Object setLogoOffsetBottomY = valueForKey(shanYanUIConfig, "setLogoOffsetBottomY");
        Object setLogoHidden = valueForKey(shanYanUIConfig, "setLogoHidden");
        Object setLogoOffsetX = valueForKey(shanYanUIConfig, "setLogoOffsetX");

        Object setNumberColor = valueForKey(shanYanUIConfig, "setNumberColor");
        Object setNumFieldOffsetY = valueForKey(shanYanUIConfig, "setNumFieldOffsetY");
        Object setNumFieldOffsetBottomY = valueForKey(shanYanUIConfig, "setNumFieldOffsetBottomY");
        Object setNumFieldWidth = valueForKey(shanYanUIConfig, "setNumFieldWidth");
        Object setNumFieldHeight = valueForKey(shanYanUIConfig, "setNumFieldHeight");
        Object setNumberSize = valueForKey(shanYanUIConfig, "setNumberSize");
        Object setNumFieldOffsetX = valueForKey(shanYanUIConfig, "setNumFieldOffsetX");
        Object setNumberBold = valueForKey(shanYanUIConfig, "setNumberBold");
        Object setTextSizeIsdp = valueForKey(shanYanUIConfig, "setTextSizeIsdp");


        Object setLogBtnText = valueForKey(shanYanUIConfig, "setLogBtnText");
        Object setLogBtnTextColor = valueForKey(shanYanUIConfig, "setLogBtnTextColor");
        Object setLogBtnImgPath = valueForKey(shanYanUIConfig, "setLogBtnImgPath");
        Object setLogBtnOffsetY = valueForKey(shanYanUIConfig, "setLogBtnOffsetY");
        Object setLogBtnOffsetBottomY = valueForKey(shanYanUIConfig, "setLogBtnOffsetBottomY");
        Object setLogBtnTextSize = valueForKey(shanYanUIConfig, "setLogBtnTextSize");
        Object setLogBtnHeight = valueForKey(shanYanUIConfig, "setLogBtnHeight");
        Object setLogBtnWidth = valueForKey(shanYanUIConfig, "setLogBtnWidth");
        Object setLogBtnOffsetX = valueForKey(shanYanUIConfig, "setLogBtnOffsetX");
        Object setLogBtnTextBold = valueForKey(shanYanUIConfig, "setLogBtnTextBold");

        Object setAppPrivacyOne = valueForKey(shanYanUIConfig, "setAppPrivacyOne");
        Object setAppPrivacyTwo = valueForKey(shanYanUIConfig, "setAppPrivacyTwo");
        Object setAppPrivacyThree = valueForKey(shanYanUIConfig, "setAppPrivacyThree");
        Object setPrivacySmhHidden = valueForKey(shanYanUIConfig, "setPrivacySmhHidden");
        Object setPrivacyTextSize = valueForKey(shanYanUIConfig, "setPrivacyTextSize");
        Object setPrivacyWidth = valueForKey(shanYanUIConfig, "setPrivacyWidth");
        Object setAppPrivacyColor = valueForKey(shanYanUIConfig, "setAppPrivacyColor");
        Object setPrivacyOffsetBottomY = valueForKey(shanYanUIConfig, "setPrivacyOffsetBottomY");
        Object setPrivacyOffsetY = valueForKey(shanYanUIConfig, "setPrivacyOffsetY");
        Object setPrivacyOffsetX = valueForKey(shanYanUIConfig, "setPrivacyOffsetX");
        Object setCheckBoxOffsetXY = valueForKey(shanYanUIConfig, "setCheckBoxOffsetXY");

        Object setPrivacyOffsetGravityLeft = valueForKey(shanYanUIConfig, "setPrivacyOffsetGravityLeft");
        Object setPrivacyState = valueForKey(shanYanUIConfig, "setPrivacyState");
        Object setPrivacyActivityEnabled = valueForKey(shanYanUIConfig, "setPrivacyActivityEnabled");
        Object setPrivacyGravityHorizontalCenter = valueForKey(shanYanUIConfig, "setPrivacyGravityHorizontalCenter");
        Object setUncheckedImgPath = valueForKey(shanYanUIConfig, "setUncheckedImgPath");
        Object setCheckedImgPath = valueForKey(shanYanUIConfig, "setCheckedImgPath");
        Object setCheckBoxHidden = valueForKey(shanYanUIConfig, "setCheckBoxHidden");
        Object setCheckBoxWH = valueForKey(shanYanUIConfig, "setCheckBoxWH");
        Object setCheckBoxMargin = valueForKey(shanYanUIConfig, "setCheckBoxMargin");
        Object setPrivacyText = valueForKey(shanYanUIConfig, "setPrivacyText");
        Object setPrivacyTextBold = valueForKey(shanYanUIConfig, "setPrivacyTextBold");
        Object setCheckBoxTipDisable = valueForKey(shanYanUIConfig, "setCheckBoxTipDisable");
        Object setPrivacyCustomToastText = valueForKey(shanYanUIConfig, "setPrivacyCustomToastText");
        Object setPrivacyNameUnderline = valueForKey(shanYanUIConfig, "setPrivacyNameUnderline");
        Object setOperatorPrivacyAtLast = valueForKey(shanYanUIConfig, "setOperatorPrivacyAtLast");
        Object setPrivacyNavColor = valueForKey(shanYanUIConfig, "setPrivacyNavColor");
        Object setPrivacyNavTextBold = valueForKey(shanYanUIConfig, "setPrivacyNavTextBold");
        Object setPrivacyNavTextColor = valueForKey(shanYanUIConfig, "setPrivacyNavTextColor");
        Object setPrivacyNavTextSize = valueForKey(shanYanUIConfig, "setPrivacyNavTextSize");
        Object setPrivacyNavReturnImgPath = valueForKey(shanYanUIConfig, "setPrivacyNavReturnImgPath");
        Object setPrivacyNavReturnImgHidden = valueForKey(shanYanUIConfig, "setPrivacyNavReturnImgHidden");
        Object setPrivacyNavReturnBtnWidth = valueForKey(shanYanUIConfig, "setPrivacyNavReturnBtnWidth");
        Object setPrivacyNavReturnBtnHeight = valueForKey(shanYanUIConfig, "setPrivacyNavReturnBtnHeight");
        Object setPrivacyNavReturnBtnOffsetRightX = valueForKey(shanYanUIConfig, "setPrivacyNavReturnBtnOffsetRightX");
        Object setPrivacyNavReturnBtnOffsetX = valueForKey(shanYanUIConfig, "setPrivacyNavReturnBtnOffsetX");
        Object setPrivacyNavReturnBtnOffsetY = valueForKey(shanYanUIConfig, "setPrivacyNavReturnBtnOffsetY");

        Object addCustomPrivacyAlertView = valueForKey(shanYanUIConfig, "addCustomPrivacyAlertView");

        Object setLoadingView = valueForKey(shanYanUIConfig, "setLoadingView");
        Object setDialogTheme = valueForKey(shanYanUIConfig, "setDialogTheme");
        Object setActivityTranslateAnim = valueForKey(shanYanUIConfig, "setActivityTranslateAnim");
        if (0 != getLayoutForId((String) setLoadingView)) {
            RelativeLayout.LayoutParams mLayoutParams3 = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
            RelativeLayout view_dialog = (RelativeLayout) LayoutInflater.from(context).inflate(getLayoutForId((String) setLoadingView), null);
            view_dialog.setLayoutParams(mLayoutParams3);
            builder.setLoadingView(view_dialog);
        }
        if (0 != getLayoutForId((String) addCustomPrivacyAlertView)) {
            RelativeLayout.LayoutParams mLayoutParamsAlert = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
            RelativeLayout privacyAlertView = (RelativeLayout) LayoutInflater.from(context).inflate(getLayoutForId((String) addCustomPrivacyAlertView), null);
            privacyAlertView.setLayoutParams(mLayoutParamsAlert);
            builder.addCustomPrivacyAlertView(privacyAlertView);
        }
        //授权页背景
        if (null != isFinish) {
            this.isFinish = (Boolean) isFinish;
        }
        if (null != getDrawableByReflect(setAuthBGImgPath)) {
            builder.setAuthBGImgPath(getDrawableByReflect(setAuthBGImgPath));
        }
        if (null != setAuthBgGifPath) {
            builder.setAuthBgGifPath((String) setAuthBgGifPath);
        }
        if (null != setAuthBgVideoPath) {
            int bgVideoId = getRawForId((String) setAuthBgVideoPath);
            if (bgVideoId != 0) {
                String bgVideoPath = "android.resource://" + context.getPackageName() + "/" + bgVideoId;
                builder.setAuthBgVideoPath(bgVideoPath);
            }
        }
        //状态栏
        if (null != setStatusBarColor) {
            builder.setStatusBarColor(Color.parseColor((String) setStatusBarColor));
        }
        if (null != setLogBtnBackgroundColor) {
            builder.setLogBtnBackgroundColor(Color.parseColor((String) setLogBtnBackgroundColor));
        }
        if (null != setLightColor) {
            builder.setLightColor((Boolean) setLightColor);
        }
        if (null != setStatusBarHidden) {
            builder.setStatusBarHidden((Boolean) setStatusBarHidden);
        }
        if (null != setVirtualKeyTransparent) {
            builder.setVirtualKeyTransparent((Boolean) setVirtualKeyTransparent);
        }
        if (null != setAuthFlagSecureEnable) {
            builder.setAuthFlagSecureEnable((Boolean) setAuthFlagSecureEnable);
        }
        if (null != setPrivacyFlagSecureEnable) {
            builder.setPrivacyFlagSecureEnable((Boolean) setPrivacyFlagSecureEnable);
        }

        //导航栏
        if (null != setFullScreen) {
            builder.setFullScreen((Boolean) setFullScreen);
        }
        if (null != setNavColor) {
            builder.setNavColor(Color.parseColor((String) setNavColor));
        }
        if (null != setNavText) {
            builder.setNavText((String) setNavText);
        }
        if (null != setNavTextColor) {
            builder.setNavTextColor(Color.parseColor((String) setNavTextColor));
        }
        if (null != setNavTextSize) {
            builder.setNavTextSize((Integer) setNavTextSize);
        }
        if (null != setNavReturnImgPath) {
            builder.setNavReturnImgPath(getDrawableByReflect(setNavReturnImgPath));
        }
        if (null != setNavReturnImgHidden) {
            builder.setNavReturnImgHidden((Boolean) setNavReturnImgHidden);
        }
        if (null != setBackPressedAvailable) {
            builder.setBackPressedAvailable((Boolean) setBackPressedAvailable);
        }
        if (null != setFitsSystemWindows) {
            builder.setFitsSystemWindows((Boolean) setFitsSystemWindows);
        }
        if (null != setNavReturnBtnWidth) {
            builder.setNavReturnBtnWidth((Integer) setNavReturnBtnWidth);
        }
        if (null != setNavReturnBtnHeight) {
            builder.setNavReturnBtnHeight((Integer) setNavReturnBtnHeight);
        }
        if (null != setNavReturnBtnOffsetRightX) {
            builder.setNavReturnBtnOffsetRightX((Integer) setNavReturnBtnOffsetRightX);
        }
        if (null != setNavReturnBtnOffsetX) {
            builder.setNavReturnBtnOffsetX((Integer) setNavReturnBtnOffsetX);
        }
        if (null != setNavReturnBtnOffsetY) {
            builder.setNavReturnBtnOffsetY((Integer) setNavReturnBtnOffsetY);
        }
        if (null != setAuthNavHidden) {
            builder.setAuthNavHidden((Boolean) setAuthNavHidden);
        }
        if (null != setAuthNavTransparent) {
            builder.setAuthNavTransparent((Boolean) setAuthNavTransparent);
        }
        if (null != setNavTextBold) {
            builder.setNavTextBold((Boolean) setNavTextBold);
        }
        // 授权页logo
        if (null != setLogoImgPath) {
            builder.setLogoImgPath(getDrawableByReflect(setLogoImgPath));
        }
        if (null != setLogoWidth) {
            builder.setLogoWidth((Integer) setLogoWidth);
        }
        if (null != setLogoHeight) {
            builder.setLogoHeight((Integer) setLogoHeight);
        }
        if (null != setLogoOffsetY) {
            builder.setLogoOffsetY((Integer) setLogoOffsetY);
        }
        if (null != setLogoOffsetBottomY) {
            builder.setLogoOffsetBottomY((Integer) setLogoOffsetBottomY);
        }
        if (null != setLogoHidden) {
            builder.setLogoHidden((Boolean) setLogoHidden);
        }
        if (null != setLogoOffsetX) {
            builder.setLogoOffsetX((Integer) setLogoOffsetX);
        }
        // 授权页 号码栏
        if (null != setNumberColor) {
            builder.setNumberColor(Color.parseColor((String) setNumberColor));
        }
        if (null != setNumFieldOffsetY) {
            builder.setNumFieldOffsetY((Integer) setNumFieldOffsetY);
        }
        if (null != setNumFieldOffsetBottomY) {
            builder.setNumFieldOffsetBottomY((Integer) setNumFieldOffsetBottomY);
        }
        if (null != setNumFieldWidth) {
            builder.setNumFieldWidth((Integer) setNumFieldWidth);
        }
        if (null != setNumFieldHeight) {
            builder.setNumFieldHeight((Integer) setNumFieldHeight);
        }
        if (null != setNumberSize) {
            builder.setNumberSize((Integer) setNumberSize);
        }
        if (null != setNumFieldOffsetX) {
            builder.setNumFieldOffsetX((Integer) setNumFieldOffsetX);
        }
        if (null != setNumberBold) {
            builder.setNumberBold((Boolean) setNumberBold);
        }
        if (null != setTextSizeIsdp) {
            builder.setTextSizeIsdp((Boolean) setTextSizeIsdp);
        }

        //授权页 登录按钮

        if (null != setLogBtnText) {
            builder.setLogBtnText((String) setLogBtnText);
        }
        if (null != setLogBtnTextColor) {
            builder.setLogBtnTextColor(Color.parseColor((String) setLogBtnTextColor));
        }
        if (null != setLogBtnImgPath) {
            builder.setLogBtnImgPath(getDrawableByReflect(setLogBtnImgPath));
        }
        if (null != setLogBtnOffsetY) {
            builder.setLogBtnOffsetY((Integer) setLogBtnOffsetY);
        }
        if (null != setLogBtnOffsetBottomY) {
            builder.setLogBtnOffsetBottomY((Integer) setLogBtnOffsetBottomY);
        }
        if (null != setLogBtnTextSize) {
            builder.setLogBtnTextSize((Integer) setLogBtnTextSize);
        }
        if (null != setLogBtnHeight) {
            builder.setLogBtnHeight((Integer) setLogBtnHeight);
        }
        if (null != setLogBtnWidth) {
            builder.setLogBtnWidth((Integer) setLogBtnWidth);
        }
        if (null != setLogBtnOffsetX) {
            builder.setLogBtnOffsetX((Integer) setLogBtnOffsetX);
        }
        if (null != setLogBtnTextBold) {
            builder.setLogBtnTextBold((Boolean) setLogBtnTextBold);
        }
        //授权页 隐私协议栏
        if (null != setAppPrivacyOne) {
            ArrayList<String> setAppPrivacyOneList = (ArrayList) setAppPrivacyOne;
            setAppPrivacyOneList.addAll(Arrays.asList("", ""));
            builder.setAppPrivacyOne(setAppPrivacyOneList.get(0), setAppPrivacyOneList.get(1));
        }
        if (null != setAppPrivacyTwo) {
            ArrayList<String> setAppPrivacyTwoList = (ArrayList) setAppPrivacyTwo;
            setAppPrivacyTwoList.addAll(Arrays.asList("", ""));
            builder.setAppPrivacyTwo(setAppPrivacyTwoList.get(0), setAppPrivacyTwoList.get(1));
        }
        if (null != setAppPrivacyThree) {
            ArrayList<String> setAppPrivacyThreeList = (ArrayList) setAppPrivacyThree;
            setAppPrivacyThreeList.addAll(Arrays.asList("", ""));
            builder.setAppPrivacyThree(setAppPrivacyThreeList.get(0), setAppPrivacyThreeList.get(1));
        }
        if (null != setPrivacySmhHidden) {
            builder.setPrivacySmhHidden((Boolean) setPrivacySmhHidden);
        }
        if (null != setPrivacyTextSize) {
            builder.setPrivacyTextSize((Integer) setPrivacyTextSize);
        }
        if (null != setPrivacyWidth) {
            builder.setPrivacyWidth((Integer) setPrivacyWidth);
        }
        if (null != setAppPrivacyColor) {
            ArrayList<String> setAppPrivacyColorList = (ArrayList) setAppPrivacyColor;
            setAppPrivacyColorList.addAll(Arrays.asList("", ""));
            builder.setAppPrivacyColor(Color.parseColor(setAppPrivacyColorList.get(0)), Color.parseColor(setAppPrivacyColorList.get(1)));
        }
        if (null != setPrivacyOffsetBottomY) {
            builder.setPrivacyOffsetBottomY((Integer) setPrivacyOffsetBottomY);
        }
        if (null != setPrivacyOffsetY) {
            builder.setPrivacyOffsetY((Integer) setPrivacyOffsetY);
        }
        if (null != setPrivacyOffsetX) {
            builder.setPrivacyOffsetX((Integer) setPrivacyOffsetX);
        }
        if (null != setPrivacyOffsetGravityLeft) {
            builder.setPrivacyOffsetGravityLeft((Boolean) setPrivacyOffsetGravityLeft);
        }
        if (null != setPrivacyState) {
            builder.setPrivacyState((Boolean) setPrivacyState);
        }
        if (null != setPrivacyActivityEnabled) {
            builder.setPrivacyActivityEnabled((Boolean) setPrivacyActivityEnabled);
        }
        if (null != setPrivacyGravityHorizontalCenter) {
            builder.setPrivacyGravityHorizontalCenter((Boolean) setPrivacyGravityHorizontalCenter);
        }
        if (null != setUncheckedImgPath) {
            builder.setUncheckedImgPath(getDrawableByReflect(setUncheckedImgPath));
        }
        if (null != setCheckedImgPath) {
            builder.setCheckedImgPath(getDrawableByReflect(setCheckedImgPath));
        }
        if (null != setCheckBoxHidden) {
            builder.setCheckBoxHidden((Boolean) setCheckBoxHidden);
        }
        if (null != setCheckBoxOffsetXY) {
            ArrayList<Integer> setcheckBoxOffsetXYList = (ArrayList) setCheckBoxOffsetXY;
            setcheckBoxOffsetXYList.addAll(Arrays.asList(0, 0));
            builder.setcheckBoxOffsetXY(setcheckBoxOffsetXYList.get(0), setcheckBoxOffsetXYList.get(1));
        }

        if (null != setCheckBoxWH) {
            ArrayList<Integer> setCheckBoxWHList = (ArrayList) setCheckBoxWH;
            setCheckBoxWHList.addAll(Arrays.asList(0, 0));
            builder.setCheckBoxWH(setCheckBoxWHList.get(0), setCheckBoxWHList.get(1));
        }
        if (null != setCheckBoxMargin) {
            ArrayList<Integer> setCheckBoxMarginList = (ArrayList) setCheckBoxMargin;
            setCheckBoxMarginList.addAll(Arrays.asList(0, 0, 0, 0));
            builder.setCheckBoxMargin(setCheckBoxMarginList.get(0), setCheckBoxMarginList.get(1), setCheckBoxMarginList.get(2), setCheckBoxMarginList.get(3));
        }
        if (null != setPrivacyText) {
            ArrayList<String> setPrivacyTextList = (ArrayList) setPrivacyText;
            setPrivacyTextList.addAll(Arrays.asList("", "", "", "", ""));
            builder.setPrivacyText(setPrivacyTextList.get(0), setPrivacyTextList.get(1), setPrivacyTextList.get(2), setPrivacyTextList.get(3), setPrivacyTextList.get(4));
        }
        if (null != setPrivacyTextBold) {
            builder.setPrivacyTextBold((Boolean) setPrivacyTextBold);
        }
        if (null != setCheckBoxTipDisable) {
            builder.setCheckBoxTipDisable((Boolean) setCheckBoxTipDisable);
        }
        if (null != setPrivacyCustomToastText) {
            builder.setPrivacyCustomToastText((String) setPrivacyCustomToastText);
        }
        if (null != setPrivacyNameUnderline) {
            builder.setPrivacyNameUnderline((Boolean) setPrivacyNameUnderline);
        }
        if (null != setOperatorPrivacyAtLast) {
            builder.setOperatorPrivacyAtLast((Boolean) setOperatorPrivacyAtLast);
        }
        //协议页导航栏
        if (null != setPrivacyNavColor) {
            builder.setPrivacyNavColor(Color.parseColor((String) setPrivacyNavColor));
        }
        if (null != setPrivacyNavTextColor) {
            builder.setPrivacyNavTextColor(Color.parseColor((String) setPrivacyNavTextColor));
        }
        if (null != setPrivacyNavTextSize) {
            builder.setPrivacyNavTextSize((Integer) setPrivacyNavTextSize);
        }
        if (null != setPrivacyNavReturnImgPath) {
            builder.setPrivacyNavReturnImgPath(getDrawableByReflect(setPrivacyNavReturnImgPath));
        }
        if (null != setPrivacyNavReturnImgHidden) {
            builder.setPrivacyNavReturnImgHidden((Boolean) setPrivacyNavReturnImgHidden);
        }
        if (null != setPrivacyNavReturnBtnWidth) {
            builder.setPrivacyNavReturnBtnWidth((Integer) setPrivacyNavReturnBtnWidth);
        }
        if (null != setPrivacyNavReturnBtnHeight) {
            builder.setPrivacyNavReturnBtnHeight((Integer) setPrivacyNavReturnBtnHeight);
        }
        if (null != setPrivacyNavReturnBtnOffsetRightX) {
            builder.setPrivacyNavReturnBtnOffsetRightX((Integer) setPrivacyNavReturnBtnOffsetRightX);
        }
        if (null != setPrivacyNavReturnBtnOffsetX) {
            builder.setPrivacyNavReturnBtnOffsetX((Integer) setPrivacyNavReturnBtnOffsetX);
        }
        if (null != setPrivacyNavReturnBtnOffsetY) {
            builder.setPrivacyNavReturnBtnOffsetY((Integer) setPrivacyNavReturnBtnOffsetY);
        }
        if (null != setPrivacyNavTextBold) {
            builder.setPrivacyNavTextBold((Boolean) setPrivacyNavTextBold);
        }

        if (null != setDialogTheme) {
            ArrayList<String> setDialogThemeList = (ArrayList) setDialogTheme;
            setDialogThemeList.addAll(Arrays.asList("0", "0", "0", "0", "false"));
            builder.setDialogTheme(true, Integer.parseInt(setDialogThemeList.get(0)),
                    Integer.parseInt(setDialogThemeList.get(1)), Integer.parseInt(setDialogThemeList.get(2)),
                    Integer.parseInt(setDialogThemeList.get(3)), Boolean.parseBoolean(setDialogThemeList.get(4)));
        }
        if (null != setActivityTranslateAnim) {
            ArrayList<String> setActivityTranslateAnimList = (ArrayList) setActivityTranslateAnim;
            setActivityTranslateAnimList.addAll(Arrays.asList("0", "0"));
            builder.setActivityTranslateAnim(setActivityTranslateAnimList.get(0), setActivityTranslateAnimList.get(1));
        }

    }

    private Object valueForKey(Map para, String key) {
        if (para != null && para.containsKey(key)) {
            return para.get(key);
        } else {
            return null;
        }
    }

    private int getRawForId(String rawName) {
        Log.e(TAG, "raw_Name=" + rawName);
        if (null == rawName) {
            return 0;
        } else {
            Resources mResources = context.getResources();
            if (mResources != null) {
                return mResources.getIdentifier(rawName, "raw", context.getPackageName());
            } else {
                return 0;
            }
        }
    }

    public int getLayoutForId(String layoutname) {
        Log.e(TAG, "layout_Name=" + layoutname);
        if (null == layoutname) {
            return 0;
        } else {
            Resources mResources = context.getResources();
            if (mResources != null) {
                return mResources.getIdentifier(layoutname, "layout", context.getPackageName());
            } else {
                return 0;
            }
        }
    }

    /*
     * 取id资源
     */
    public int getId(String idname) {
        Log.e(TAG, "ResourcesId_Name=" + idname);
        if (null == idname) {
            return 0;
        } else {
            Resources mResources = context.getResources();
            if (mResources != null) {
                return mResources.getIdentifier(idname, "id", context.getPackageName());
            } else {
                return 0;
            }
        }
    }

    private Drawable getDrawableByReflect(Object imageName) {
        try {
            Log.e(TAG, "drawable_Name=" + imageName);
            Class drawable = R.drawable.class;
            Field field = null;
            int r_id = 0;
            if (null == imageName) {
                return null;
            }
            try {
                field = drawable.getField((String) imageName);
                r_id = field.getInt(field.getName());
            } catch (Exception e) {
                r_id = 0;
            }
            if (r_id == 0) {
                r_id = context.getResources().getIdentifier((String) imageName, "drawable", context.getPackageName());
            }
            if (r_id == 0) {
                r_id = context.getResources().getIdentifier((String) imageName, "mipmap", context.getPackageName());
            }
            return context.getResources().getDrawable(r_id);
        } catch (Exception e) {
            Log.e(TAG, "drawable_Name=" + imageName+e);
            return null;
        }
    }

    /**
     * 获取对齐方式
     */
    private int getAlignmentFromString(String alignmet) {
        int a = 0;
        if (alignmet != null) {
            switch (alignmet) {
                case "left":
                    a = Gravity.LEFT;
                    break;
                case "top":
                    a = Gravity.TOP;
                    break;
                case "right":
                    a = Gravity.RIGHT;
                    break;
                case "bottom":
                    a = Gravity.BOTTOM;
                    break;
                case "center":
                    a = Gravity.CENTER;
                    break;
                default:
                    a = Gravity.NO_GRAVITY;
                    break;
            }
        }
        return a;
    }

    private int dp2Pix(Context context, float dp) {
        try {
            float density = context.getResources().getDisplayMetrics().density;
            return (int) (dp * density + 0.5F);
        } catch (Exception e) {
            return (int) dp;
        }
    }
}
