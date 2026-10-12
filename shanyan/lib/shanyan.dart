import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shanYanResult.dart';
import 'shanYanUIConfig.dart';

/// 闪验SDK 授权页回调（一键登录点击/sdk自带返回）
typedef ShanYanOneKeyLoginListener = void Function(ShanYanResult shanYanResult);

/// 闪验SDK 自定义控件点击回调
typedef ShanYanWidgetEventListener = void Function(String shanYanWidgetEvent);

/// 闪验SDK 授权页点击事件监听（复选框和协议）
typedef AuthPageActionListener = void Function(AuthPageActionEvent event);

/// 闪验SDK 协议点击事件监听
typedef PricacyOnClickListener = void Function(PrivacyOnClickEvent event);

class OneKeyLoginManager {
  final ShanYanEventHandlers _eventHanders = new ShanYanEventHandlers();

  final MethodChannel _channel = const MethodChannel("shanyan");

  // 应用兼容补丁：原生事件必须匹配本次授权，关闭后立即拒绝迟到令牌。
  String? _activeRequestId;

  ShanYanUIConfig shanYanUIConfig = new ShanYanUIConfig();

  OneKeyLoginManager() {
    _channel.setMethodCallHandler(_handlerMethod);
  }

  /// 授权页控件的点击事件（“复选框”、"协议"） Android
  setAuthPageActionListener(AuthPageActionListener callback) {
    _channel.invokeMethod("setActionListener");
    _eventHanders.authPageActionListener = callback;
  }

  /// 授权页协议点击事件
  setPrivacyOnClickListener(PricacyOnClickListener callback) {
    _channel.invokeMethod("setPrivacyOnClickListener");
    _eventHanders.pricacyOnClickListener = callback;
  }

  /// 关闭或开启 Android 调试日志，并等待原生执行回执。
  Future<void> setDebug(bool debug) async {
    await _channel.invokeMethod<void>("setDebugMode", {"debug": debug});
  }

  /// 设置详细调试模式开关 (Android + iOS)
  Future<void> setInitDebug(bool debug) async {
    await _channel.invokeMethod<void>("setInitDebug", {"initDebug": debug});
  }

  /// 设置预取号超时时间（单位：秒）(Android + iOS)
  Future<void> setTimeOutForPreLogin(int timeOut) async {
    await _channel.invokeMethod<void>("setTimeOutForPreLogin", {"timeOut": timeOut});
  }

  /// 设置是否获取OAID
  Future<void> getOaidEnable(bool oaidEnable) async {
    await _channel.invokeMethod<void>("getOaidEnable", {"oaidEnable": oaidEnable});
  }

  /// 设置是否获取iccid
  Future<void> getSinbEnable(bool sinbEnable) async {
    await _channel.invokeMethod<void>("getSinbEnable", {"sinbEnable": sinbEnable});
  }

  /// 设置是否获取IMSI
  Future<void> getSiEnable(bool sibEnable) async {
    await _channel.invokeMethod<void>("getSiEnable", {"sibEnable": sibEnable});
  }

  /// 设置是否获取IP(Android + iOS)
  Future<void> getIEnable(bool iEnable) async {
    await _channel.invokeMethod<void>("getIEnable", {"iEnable": iEnable});
  }

  /// 设置是否获取Mac地址
  Future<void> getMaEnable(bool maEnable) async {
    await _channel.invokeMethod<void>("getMaEnable", {"maEnable": maEnable});
  }

  /// 设置是否获取IMEI
  Future<void> getImEnable(bool imEnable) async {
    await _channel.invokeMethod<void>("getImEnable", {"imEnable": imEnable});
  }

  /// 设置是否设置监听生命周期
  void setActivityLifecycleCallbacksEnable(bool enable) {
    _channel.invokeMethod("setActivityLifecycleCallbacksEnable",
        {"activityLifecycleCallbacksEnable": enable});
  }

  ///设置是否判断方法是否在主进程调用
  void checkProcessesEnable(bool enable) {
    _channel
        .invokeMethod("checkProcessesEnable", {"checkProcessesEnable": enable});
  }

  /// 获取运营商类型
  Future<String> getOperatorType() async {
    return await _channel.invokeMethod("getOperatorType");
  }

  /// 获取运营商信息（协议名称、链接、运营商类型）
  Future<String> getOperatorInfo() async {
    return await _channel.invokeMethod("getOperatorInfo");
  }

  ///闪验SDK 初始化(Android+iOS)
  Future<ShanYanResult> init({required String appId}) async {
    Map result = await _channel.invokeMethod("init", {"appId": appId});
    Map<String, dynamic> newResult = new Map<String, dynamic>.from(result);
    return ShanYanResult.fromJson(newResult);
  }

  ///闪验SDK 预取号(Android+iOS)
  Future<ShanYanResult> getPhoneInfo() async {
    Map<dynamic, dynamic> result = await _channel.invokeMethod("getPhoneInfo");
    Map<String, dynamic> newResult = new Map<String, dynamic>.from(result);
    return ShanYanResult.fromJson(newResult);
  }

  /// 设置授权页一键登录回调（“一键登录按钮”、返回按钮（包括物理返回键）） (Android+iOS)
  setOneKeyLoginListener(ShanYanOneKeyLoginListener callback) {
    _eventHanders.oneKeyLoginListener = callback;
  }

  /// 自定义控件的点击事件 Android
  addClikWidgetEventListener(ShanYanWidgetEventListener callback) {
    _eventHanders.shanYanWidgetEventListener = callback;
  }

  /// 拉起授权页，并以 [requestId] 隔离原生迟到事件；回执不是登录令牌。
  Future<ShanYanResult> openLoginAuth({required String requestId}) async {
    _activeRequestId = requestId;
    if (Platform.isAndroid) {
      Map<dynamic, dynamic> result =
          await _channel.invokeMethod("openLoginAuth", {"requestId": requestId});
      Map<String, dynamic> newResult = new Map<String, dynamic>.from(result);
      return ShanYanResult.fromJson(newResult);
    } else if (Platform.isIOS) {
      Map iosConfigure = this.shanYanUIConfig.ios.toJson();
      iosConfigure["requestId"] = requestId;
      Map<dynamic, dynamic> result =
          await _channel.invokeMethod("openLoginAuth", iosConfigure);
      Map<String, dynamic> newResult = new Map<String, dynamic>.from(result);
      return ShanYanResult.fromJson(newResult);
    } else {
      return ShanYanResult(code: 1003, message: "拉起授权页失败,暂不支持此设备");
    }
  }

  /// 立即使本轮事件失效并关闭授权页；回执不代表上游网络请求已取消。
  Future<void> finishAuthControllerCompletion() async {
    _activeRequestId = null;
    if (Platform.isIOS) {
      return await _channel.invokeMethod("finishAuthControllerCompletion");
    } else if (Platform.isAndroid) {
      return await _channel.invokeMethod("finishAuthActivity");
    }
  }

//  Future<void> alertNativeIOS(String title,String message,String cancelButtonTitle,String okButtonTitle,String otherButtonTitle) async {
//    Map alert = {
//      "title":title,
//      "message":message,
//      "cancelButtonTitle":cancelButtonTitle,
//      "okButtonTitle": okButtonTitle,
//      "otherButtonTitle":otherButtonTitle
//    };
//
//    Map<dynamic, dynamic> result = await _channel.invokeMethod("alertNative",alert);
//    Map<String, dynamic> newResult = new Map<String, dynamic>.from(result);
//    return ShanYanResult.fromJson(newResult);
//  }

//
  ///闪验SDK 设置复选框是否选中 Android+IOS
  void setCheckBoxValue(bool isChecked) {
    _channel.invokeMethod("setCheckBoxValue", {"isChecked": isChecked});
  }

  ///闪验SDK 设置授权页loading是否隐藏 Android+IOS
  void setLoadingVisibility(bool visibility) {
    _channel.invokeMethod("setLoadingVisibility", {"visibility": visibility});
  }

  ///闪验SDK 本机号校验获取token (Android+iOS)
  Future<ShanYanResult> startAuthentication() async {
    Map<dynamic, dynamic> result =
        await _channel.invokeMethod("startAuthentication");
    Map<String, dynamic> newResult = new Map<String, dynamic>.from(result);
    return ShanYanResult.fromJson(newResult);
  }

  /// 清除预取号缓存
  Future<void> clearScripCache() async {
    await _channel.invokeMethod<void>("clearScripCache");
  }

  /// 清理回调监听
  Future<void> removeAllListener() async {
    await _channel.invokeMethod<void>("removeAllListener");
  }

  // /// 获取授权页协议勾选框CheckBox对象
  // Future<Checkbox> getPrivacyCheckBox() async {
  //   return await _channel.invokeMethod("getPrivacyCheckBox");
  // }

  /// 触发登录按钮(Android + iOS)
  void performLoginClick() {
    _channel.invokeMethod("performLoginClick");
  }

  ///闪验SDK 配置授权页 Android
  Future<void> setAuthThemeConfig({required ShanYanUIConfig uiConfig}) async {
    shanYanUIConfig = uiConfig;
    if (Platform.isAndroid) {
      Map<String, dynamic> uiConfigJson = uiConfig.toJson();
      await _channel.invokeMethod<void>("setAuthThemeConfig", uiConfigJson);
    }
  }

  //Android
  Future<void> _handlerMethod(MethodCall call) async {
    switch (call.method) {
      case 'onReceiveAuthPageEvent':
        Map<String, dynamic> newResult =
            new Map<String, dynamic>.from(call.arguments);
        // 原生闭包携带发起时的编号，不能把旧页面的成功事件转交新页面。
        if (_activeRequestId == null ||
            newResult["requestId"] != _activeRequestId) return;
        ShanYanResult result = ShanYanResult.fromJson(newResult);
        _eventHanders.oneKeyLoginListener?.call(result);
        break;
      case 'onReceiveClickWidgetEvent':
        {
          String widgetId = call.arguments.cast<dynamic, dynamic>()['widgetId'];
          print("点击了：" + widgetId);
          // ignore: unnecessary_null_comparison
          if (null != widgetId) {
            _eventHanders.shanYanWidgetEventListener?.call(widgetId);
          }
        }
        break;
      case 'onReceiveAuthEvent':
        Map json = call.arguments.cast<dynamic, dynamic>();
        AuthPageActionEvent ev = AuthPageActionEvent.fromJson(json);
        _eventHanders.authPageActionListener?.call(ev);
        break;
      case 'onReceivePrivacyEvent':
        Map json = call.arguments.cast<dynamic, dynamic>();
        PrivacyOnClickEvent ev = PrivacyOnClickEvent.fromJson(json);
        _eventHanders.pricacyOnClickListener?.call(ev);
        break;
      default:
        throw new UnsupportedError("Unrecognized Event");
    }
  }
}

/// 闪验SDK 授权页默认控件点击事件
class AuthPageActionEvent {
  final int type; //类型
  final int code; //返回码
  final String message; //事件描述

  AuthPageActionEvent.fromJson(Map<dynamic, dynamic> json)
      : type = json['type'],
        code = json['code'],
        message = json['message'];

  Map toMap() {
    return {'type': type, 'code': code, 'message': message};
  }
}

/// 闪验SDK 授权页协议点击事件
class PrivacyOnClickEvent {
  final String url; //协议名称
  final String name; //协议链接

  PrivacyOnClickEvent.fromJson(Map<dynamic, dynamic> json)
      : url = json['url'],
        name = json['name'];

  Map toMap() {
    return {'url': url, 'name': name};
  }
}

/// 闪验SDK 自定义控件点击事件
class ShanYanWidgetEvent {
  final String widgetLayoutId; //点击的控件id
  ShanYanWidgetEvent.fromJson(Map<dynamic, dynamic> json)
      : widgetLayoutId = json['widgetLayoutId'];

  Map toMap() {
    return {'widgetLayoutId': widgetLayoutId};
  }
}

class ShanYanEventHandlers {
  ShanYanOneKeyLoginListener? oneKeyLoginListener;
  ShanYanWidgetEventListener? shanYanWidgetEventListener;
  AuthPageActionListener? authPageActionListener;
  PricacyOnClickListener? pricacyOnClickListener;
}

//
//String getStringFromEnum<T>(T) {
//  if (T == null) {
//    return null;
//  }
//
//  return T.toString().split('.').last;
//}
