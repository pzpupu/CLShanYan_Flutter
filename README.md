# CLShanYan_Flutter 维护说明

本 fork 在 `ai-love-sdk-compat` 分支维护，远端为 `git@github.com:pzpupu/CLShanYan_Flutter.git`。Flutter package 位于 `shanyan/`；Dart 版本字段沿用上游 `2.3.4`，Android/iOS 原生 SDK 均固定为 `2.3.7.7`，不修改厂商 JAR/SO/framework。

消费工程通过 Git submodule 固定提交，再以 `path` 指向 `shanyan/`。分支用于开发，gitlink 用于复现；子模块内未提交的修改不会被消费工程的普通提交包含。提交与推送遵循消费工程的明确授权，不自动跟随远端分支头。

## 维护边界

- 本仓库负责通用 Dart 配置、序列化、平台桥接、原生回执和请求代际隔离，不承载产品品牌、业务协议、预取号调度、页面路由或后端认证。
- `ShanYanUIConfig` 的平台配置和 iOS 方向布局支持直接替换；iOS 横竖屏布局统一读取公开的 `set*` 字段。
- `iOSTextAlignment` 与 UIKit 对应：left=0、center=1、right=2、justified=3、natural=4，标准授权控件与自定义控件使用同一契约。
- `ShanYanCustomWidget` / `ShanYanCustomWidgetIOS` 的 `isBackground=true` 表示背景装饰：位于页面背景上方、标准授权控件下方，不接收触摸或读屏焦点，不触发关闭。默认仍为普通控件。
- `numberOfLines` 接受非负整数；`0` 自然换行且不限行数，省略时保留原生默认。设置多行仍需调用方提供足够宽高，不自动滚动或缩字。
- Android 字体参数使用 SP，系统会缩放；调用方只对几何测量应用系统比例，不把已缩放字号再次传给 SP。iOS 字号使用点值，由调用方按系统比例计算。
- 自定义 Button 支持 `textBold`、`contentPadding=[左,上,右,下]`、`pressedOverlayColor`、`pressedScale` 和 `animationDuration`；状态反馈不覆盖 SDK 点击。透明文字按钮不增加常驻底色或投影。取消、拖出、释放和禁用恢复正常外观，不增加减少动画/读屏模式开关或人工分支。
- 标准登录按钮支持 `setLogBtnElevation`、`setLogBtnShadowColor`、`setLogBtnPressedScale`、`setLogBtnPressedOverlayColor` 和 `setLogBtnAnimationDuration`。ARGB 保留透明度；Android21起支持原生 elevation，28起支持自定义阴影色，较早系统仍使用平台阴影色，不暗中提高最低版本。
- 背景装饰支持 `cornerRadius`、`borderColor/borderWidth`、`shadowColor/shadowBlurRadius/shadowSpreadRadius/shadowOffset`。`shadowOffset` 为 `[x,y]`，负 spread 收缩阴影轮廓；配置 frame 仍表示内容本体，阴影不抬高装饰的 Z 顺序或拦截输入。iOS 为 Core Animation，Android 为原生绘制，不能据同一数值承诺逐像素一致。
- `setSloganTextSuffix` 只追加真实运营商原文，重复生命周期不会重复追加。Android可用 `setSloganWidth` 限定自然换行宽度；调用方必须为后续控件预留高度，不按号码或文案猜运营商。
- 插件不接管 SDK 根视图、系统约束或滚动容器。页面方向、品牌资源和布局由消费工程配置；原生代码或资源修改需要完整重建。

## 授权页失败反馈

消费方将 Android `isFinish=false`、iOS `isFinish=true`（映射为 `manualDismiss`），在每次 SDK token 回调中完成自己的后端认证；**收到 token 不等于业务登录成功**。后端请求期间保留授权页和 SDK loading，成功后才 `await finishAuthControllerCompletion()`；失败后依次：

```dart
await oneKeyLoginManager.setLoadingVisibility(false);
await oneKeyLoginManager.showAuthError(message);
```

- `Future<void> setLoadingVisibility(bool visibility)`：Android 支持显示、隐藏；iOS 2.3.7.7 的公开 `CLShanYanSDKManager.h` 仅提供 `hideLoading`，因此 `true` 明确返回 `PlatformException(code: 'unsupported_operation')`，不再无声假成功。两端正常重试均不需要传 `true`。
- `Future<void> showAuthError(String message)`：在 SDK 原生授权页上展示非阻塞 toast，提交展示后立即完成，不等待自动消失、不要求确认或拦截点击。Android 使用系统 `Toast.LENGTH_LONG`；iOS 使用安全区内不可交互的原生消息视图，5秒后自动移除。取消、主动关页和引擎卸载清理提示；认证单飞只保持到展示回执，不覆盖 toast 的显示时长。
- 两条命令携带发出时的 `requestId`，原生拒绝失效页面（`auth_page_unavailable`）；重复反馈替换旧 toast，不排队或报“已有弹窗”。错误不会落到被原生页遮住的 Flutter SnackBar。调用方仍须丢弃已经结束的业务任务，不能把旧业务结果重新标成新页面请求。
- iOS 不再额外延迟 0.1 秒后调用全局 `hideLoading`。在主线程校验页面后立即调用官方方法，回执排在 SDK 已排队的移除动作之后；SDK 捕获的是当页 view，不会让旧隐藏任务作用于新页。

### 固定 2.3.7.7 的 loading 与重试依据

- [官方 Flutter 文档](https://doc.chuanglan.com/document/BWMTAY0S6CKR93BS)说明 Android 按钮点击会自动显示 loading，`setLoadingVisibility` 不改变这一点击行为。固定 JAR 的字节码也显示，每次已勾选登录点击都会执行 `ShanYanOneKeyActivity.o()` → `y()` → loading `setVisibility(VISIBLE)`；公开隐藏方法只将同一 loading 设为 `GONE`，不禁用后续自动显示。
- [官方 iOS 文档第 6 节](https://doc.chuanglan.com/docs/ISLGFM1T6JNCP6J8)明确支持在 SDK 失败或后端换号失败后调用 `hideLoading`，再次点击同页按钮。固定 framework 的 `loginButtonClick:` 在每次有效点击调用内置或自定义 `showLoading`；`hideLoading` 只对当前页排队移除蒙版与子视图，不设置“下次不显示”状态。桥接不调用这些私有实现，仅以其二进制行为核对公开接口契约。
- **iOS 每页最多 4 次有效登录点击。** 固定 framework 在第 5 次点击先发 `type=3/code=1` 的普通点击事件，然后禁用按钮并直接返回：没有新的 token/错误结果回调，不显示/隐藏 loading，也不自动关页。调用方不能等待一个不存在的“次数超限”错误码；需在多次失败时引导用户选择其他登录方式或自行结束后重新授权，不承诺无限同页重试，也不绕过 SDK 限额。

上述依据是官方文档、公开头文件与固定二进制分析，不等于真实运营商链路验收。设备验收应覆盖后端失败、toast仍可见时同页重试、自动消失、成功才关闭，以及取消/重开时旧反馈不串页；原生修改须完整重建。Android系统toast遵循[官方行为](https://developer.android.com/guide/topics/ui/notifiers/toasts)，Android12起最多两行，调用方应提供简短文案。

## 生成与检查

在 `shanyan/` 执行：

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze lib test
flutter test --no-pub --timeout 45s
```

只修改模型来源，不手改 `.g.dart`。插件有独立分析入口，示例工程独立解析；生成与 Dart 回归不能代替真实 iOS/Android 页面验收。

当前固定生成器仍提示其 analyzer 语言版本低于当前 Dart 工具链；本次生成及回归已成功，该兼容提示未通过隐藏告警处理。iOS 继续使用 CocoaPods，尚未迁移为 SwiftPM 插件。

官方接入资料：[创蓝 Flutter 文档](https://doc.chuanglan.com/document/BWMTAY0S6CKR93BS)。详细配置示例见 [`shanyan/README.md`](shanyan/README.md)，维护变更见 [`CHANGELOG`](shanyan/CHANGELOG.md)。
