## 2026-10-12 · Flutter 工具链与授权生命周期兼容

* 基于官方 v2.3.5.1 / `1fab9f1b0cda802211361afa64ae4028edee8891`；删除未使用的运行时构建器依赖，放宽兼容的 JSON 注解约束，声明现代平台注册。
* Android 复用宿主 AGP、移除 JCenter、compileSdk 调整为36以满足当前 Flutter embedding 的 AndroidX 依赖，并修正资源压缩保留语法；不提高应用最低版本。
* iOS 精确锁定 CL_ShanYanSDK 2.3.7.7。Android JAR/SO 及运营商二进制保持官方原样。
* 补全授权流程使用的异步调用回执、iOS 主线程回传；`openLoginAuth` 必须传入当次唯一 `requestId`，两端原生回传并过滤旧事件，关闭立即失效；同步迁移示例调用。
* 已在消费应用完成 Dart 静态检查及18项SDK边界测试，iOS27与Android15模拟器真实SDK失败烟测均返回短信入口且未请求后端换号。模拟器不证明有效AppID、签名或三网真实取号。

## 2.3.0

* TODO: Describe initial release.

## 2.3.1

* 更新安卓iOS原生SDK，两端统一主体方法
