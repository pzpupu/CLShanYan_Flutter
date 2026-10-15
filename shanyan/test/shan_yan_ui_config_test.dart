import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shanyan/shanYanUIConfig.dart';

void main() {
  group('公开配置替换', () {
    test('三端配置赋值替换原实例且序列化使用新对象', () {
      final config = ShanYanUIConfig();
      final previousIOS = config.ios;
      final previousPortrait = config.androidPortrait;
      final previousLandscape = config.androidLandscape;
      final ios = ShanYanUIConfigIOS()..setAuthNavHidden = true;
      final portrait = ShanYanUIConfigAndroid()..setNumFieldOffsetY = 0;
      final landscape = ShanYanUIConfigAndroid()..setNumFieldOffsetY = 42;

      config
        ..ios = ios
        ..androidPortrait = portrait
        ..androidLandscape = landscape;

      expect(config.ios, same(ios));
      expect(config.androidPortrait, same(portrait));
      expect(config.androidLandscape, same(landscape));
      expect(config.ios, isNot(same(previousIOS)));
      expect(config.androidPortrait, isNot(same(previousPortrait)));
      expect(config.androidLandscape, isNot(same(previousLandscape)));
      final json = config.toJson();
      expect(json['ios']['setAuthNavHidden'], isTrue);
      expect(json['androidPortrait']['setNumFieldOffsetY'], 0);
      expect(json['androidLandscape']['setNumFieldOffsetY'], 42);
    });

    test('iOS横竖屏布局可独立替换，旧对象修改不影响新布局', () {
      final config = ShanYanUIConfigIOS();
      final oldPortrait = config.layOutPortrait;
      final oldLandscape = config.layOutLandscape;
      final portrait = ClOrientationLayOutIOS()..setNumFieldTop = 0;
      final landscape = ClOrientationLayOutIOS()..setNumFieldTop = 91.5;
      config
        ..layOutPortrait = portrait
        ..layOutLandscape = landscape;
      oldPortrait.setNumFieldTop = 999;
      oldLandscape.setNumFieldTop = 999;

      expect(config.layOutPortrait, same(portrait));
      expect(config.layOutLandscape, same(landscape));
      expect(config.toJson()['layOutPortrait']['setNumFieldTop'], 0);
      expect(config.toJson()['layOutLandscape']['setNumFieldTop'], 91.5);
    });

    test('完整JSON反序列化保留所有平台与横竖屏配置，不退回空默认值', () {
      final original = ShanYanUIConfig()
        ..ios = (ShanYanUIConfigIOS()
          ..layOutPortrait = (ClOrientationLayOutIOS()
            ..setLogoTop = 0
            ..setNumFieldTop = 100.5
            ..setLogBtnTop = 150
            ..setPrivacyBottom = 24
            ..setSloganTop = 200)
          ..layOutLandscape = (ClOrientationLayOutIOS()
            ..setLogoTop = 10
            ..setNumFieldTop = 50
            ..setLogBtnTop = 90
            ..setPrivacyBottom = 12
            ..setSloganTop = 120))
        ..androidPortrait = (ShanYanUIConfigAndroid()
          ..setPrivacyState = false
          ..setNumFieldOffsetY = 100)
        ..androidLandscape = (ShanYanUIConfigAndroid()
          ..setPrivacyState = true
          ..setNumFieldOffsetY = 50);

      // 经过真正的JSON编码，不能仅靠同一Map实例掩盖嵌套对象序列化错误。
      final json = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      final restored = ShanYanUIConfig.fromJson(json);
      expect(restored.toJson(), json);
      expect(restored.ios.layOutPortrait.setNumFieldTop, 100.5);
      expect(restored.ios.layOutLandscape.setNumFieldTop, 50);
      expect(restored.androidPortrait.setPrivacyState, isFalse);
      expect(restored.androidLandscape.setPrivacyState, isTrue);
    });
  });

  group('自定义控件序列化边界', () {
    test('未设置行数时省略字段，装饰默认关闭且可从省略字段恢复', () {
      final android =
          ShanYanCustomWidget('android', ShanYanCustomWidgetType.TextView);
      final ios =
          ShanYanCustomWidgetIOS('ios', ShanYanCustomWidgetType.TextView);
      final androidJson = android.toJson();
      final iosJson = ios.toJson();
      expect(androidJson, isNot(contains('numberOfLines')));
      expect(iosJson, isNot(contains('numberOfLines')));
      expect(androidJson['isBackground'], isFalse);
      expect(iosJson['isBackground'], isFalse);

      androidJson.remove('isBackground');
      iosJson.remove('isBackground');
      expect(ShanYanCustomWidget.fromJson(androidJson).isBackground, isFalse);
      expect(ShanYanCustomWidgetIOS.fromJson(iosJson).isBackground, isFalse);
      expect(ShanYanCustomWidget.fromJson(androidJson).numberOfLines, isNull);
      expect(ShanYanCustomWidgetIOS.fromJson(iosJson).numberOfLines, isNull);
    });

    test('显式零行保留不限行数语义，与未设置行数不同', () {
      const lines = 0;
      final android =
          ShanYanCustomWidget('android', ShanYanCustomWidgetType.Button)
            ..numberOfLines = lines
            ..isBackground = true
            ..isFinish = false;
      final ios = ShanYanCustomWidgetIOS('ios', ShanYanCustomWidgetType.Button)
        ..numberOfLines = lines
        ..isBackground = true
        ..isFinish = false;
      final androidJson = android.toJson();
      final iosJson = ios.toJson();
      expect(androidJson['numberOfLines'], lines);
      expect(iosJson['numberOfLines'], lines);
      final restoredAndroid = ShanYanCustomWidget.fromJson(androidJson);
      final restoredIOS = ShanYanCustomWidgetIOS.fromJson(iosJson);
      expect(restoredAndroid.numberOfLines, lines);
      expect(restoredIOS.numberOfLines, lines);
      expect(restoredAndroid.isBackground, isTrue);
      expect(restoredIOS.isBackground, isTrue);
      expect(restoredAndroid.isFinish, isFalse);
      expect(restoredIOS.isFinish, isFalse);
    });

    test('iOS文字对齐值遵循UIKit，不再将居左与居中颠倒', () {
      const nativeValues = {
        iOSTextAlignment.left: 0,
        iOSTextAlignment.center: 1,
        iOSTextAlignment.right: 2,
        iOSTextAlignment.justified: 3,
        iOSTextAlignment.natural: 4,
      };
      for (final entry in nativeValues.entries) {
        final widget = ShanYanCustomWidgetIOS(
            'alignment', ShanYanCustomWidgetType.TextView)
          ..textAlignment = entry.key;
        final json = widget.toJson();
        expect(json['textAlignment'], entry.value);
        expect(ShanYanCustomWidgetIOS.fromJson(json).textAlignment, entry.key);
      }
    });

    test('iOS约束保留零、负值和小数，未提供字段不强制补零', () {
      final widget =
          ShanYanCustomWidgetIOS('geometry', ShanYanCustomWidgetType.TextView)
            ..left = 0
            ..centerY = -12.5
            ..width = 215.25;
      final json = widget.toJson();
      expect(json['left'], 0);
      expect(json['centerY'], -12.5);
      expect(json['width'], 215.25);
      expect(json, isNot(contains('height')));
      final restored = ShanYanCustomWidgetIOS.fromJson(json);
      expect(restored.left, 0);
      expect(restored.centerY, -12.5);
      expect(restored.width, 215.25);
      expect(restored.height, isNull);
    });
  });
}
