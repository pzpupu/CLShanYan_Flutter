import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shanyan/shanyan.dart';

/// 通过真实 MethodChannel 解码入口发送原生事件，不替换 SDK 的代际过滤逻辑。
Future<void> emitAuthEvent({String? requestId, required String token}) async {
  const codec = StandardMethodCodec();
  final completed = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'shanyan',
    codec.encodeMethodCall(
      MethodCall('onReceiveAuthPageEvent', {
        if (requestId != null) 'requestId': requestId,
        'code': 1000,
        'token': token,
      }),
    ),
    (_) => completed.complete(),
  );
  await completed.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('shanyan');
  late OneKeyLoginManager manager;
  late List<String?> tokens;

  setUp(() {
    manager = OneKeyLoginManager();
    tokens = <String?>[];
    manager.setOneKeyLoginListener((event) => tokens.add(event.token));
  });

  tearDown(() {
    channel.setMethodCallHandler(null);
  });

  // 桌面测试宿主不展示移动原生页面，但运行 SDK 自身的请求状态与事件处理。
  test('未拉页和缺失请求编号的事件不能交付登录令牌', () async {
    await emitAuthEvent(requestId: 'unopened', token: 'before-open');
    await manager.openLoginAuth(requestId: 'active');
    await emitAuthEvent(token: 'missing-id');
    expect(tokens, isEmpty);

    await emitAuthEvent(requestId: 'active', token: 'current-token');
    expect(tokens, ['current-token']);
  });

  test('新页面只消费自身请求编号的事件，旧页面迟到事件被拒绝', () async {
    await manager.openLoginAuth(requestId: 'first');
    await manager.openLoginAuth(requestId: 'second');
    await emitAuthEvent(requestId: 'first', token: 'stale-token');
    expect(tokens, isEmpty);

    await emitAuthEvent(requestId: 'second', token: 'current-token');
    expect(tokens, ['current-token']);
  });

  test('关闭立即失效，关闭后和重新打开后的旧事件都不能泄漏', () async {
    await manager.openLoginAuth(requestId: 'closed');
    final closing = manager.finishAuthControllerCompletion();
    await emitAuthEvent(requestId: 'closed', token: 'during-close');
    await closing;
    await emitAuthEvent(requestId: 'closed', token: 'after-close');
    expect(tokens, isEmpty);

    await manager.openLoginAuth(requestId: 'reopened');
    await emitAuthEvent(requestId: 'closed', token: 'after-reopen');
    await emitAuthEvent(requestId: 'reopened', token: 'new-token');
    expect(tokens, ['new-token']);
  });
}
