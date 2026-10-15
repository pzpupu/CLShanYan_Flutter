## 2026-10-15 · 原生材质与交互反馈

* 扩展真实登录按钮投影、状态层与按压动画；自定义 Button 支持粗体、内边距和文字按钮反馈，不覆盖 SDK 点击处理。
* 背景装饰支持独立透明度、边框和负扩散阴影；Android 保持背景 Z 为0，iOS 使用独立影形，不重排 SDK 根视图。
* 在真实运营商说明后幂等追加后缀并支持多行；不修改运营商协议来源。
* 修复 iOS 登录按钮边框颜色误写填充色、contentEdgeInsets 误写 titleEdgeInsets，以及颜色跨布局生命周期的持有问题；删除无用途且可能吞掉控件触摸的根手势。
* 不提供减少动画或辅助导航分支；系统全局动画行为由平台负责。保留原生版本和既有请求编号/令牌边界。

## 2026-10-15 · 子模块维护与通用授权配置修正

* `ai-love-sdk-compat` 作为子模块维护分支，消费工程以 path 引入插件；保留原生 SDK 2.3.7.7 与请求编号隔离，不把产品业务迁入插件。
* 修正平台配置和 iOS 方向布局赋值无效问题；iOS 横竖屏统一使用 Dart 公开字段，号码对齐读取正确配置键，标准与自定义控件统一 UIKit 对齐值。
* 两端自定义控件增加非交互 `isBackground` 装饰层及 `numberOfLines`；装饰位于页面背景之上、授权内容之下，不移动 SDK 根视图或引入滚动引擎。
* 增加独立分析配置，移除无效 required 注解、空测试和示例未使用的构建依赖；生成文件由 build_runner 更新。10项插件回归与独立分析通过；消费应用已完成两端原生构建、iOS电信授权页观察和Android真实SDK失败/主题桥接烟测，不代表三网登录令牌验收。
* 停止跟踪示例工程的 `.flutter-plugins-dependencies`，由 Flutter 在本机生成，避免提交开发机器的绝对路径。

## 2026-10-12 · Flutter 工具链与授权生命周期兼容

* 基于官方 v2.3.5.1 / `1fab9f1b0cda802211361afa64ae4028edee8891`；删除未使用的运行时构建器依赖，放宽兼容的 JSON 注解约束，声明现代平台注册。
* Android 复用宿主 AGP、移除 JCenter、compileSdk 调整为36以满足当前 Flutter embedding 的 AndroidX 依赖，并修正资源压缩保留语法；不提高应用最低版本。
* 补齐联通 SDK SM2/SM3 路径实际引用的 `org.bouncycastle:bcprov-jdk18on:1.86`，不以 R8 `dontwarn` 掩盖缺失实现。
* iOS 精确锁定 CL_ShanYanSDK 2.3.7.7。Android JAR/SO 及运营商二进制保持官方原样。
* 补全授权流程使用的异步调用回执、iOS 主线程回传；`openLoginAuth` 必须传入当次唯一 `requestId`，两端原生回传并过滤旧事件，关闭立即失效；同步迁移示例调用。
* 已在消费应用完成 Dart 静态检查及18项SDK边界测试，iOS27与Android15模拟器真实SDK失败烟测均返回短信入口且未请求后端换号。模拟器不证明有效AppID、签名或三网真实取号。

## 2.3.0

* TODO: Describe initial release.

## 2.3.1

* 更新安卓iOS原生SDK，两端统一主体方法
