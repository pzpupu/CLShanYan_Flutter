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
