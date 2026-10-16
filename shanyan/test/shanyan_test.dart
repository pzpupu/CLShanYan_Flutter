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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
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

  test('隐藏 loading 等待原生回执，并绑定发出时的页面编号', () async {
    final nativeCompleted = Completer<void>();
    final received = Completer<MethodCall>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received.complete(call);
      await nativeCompleted.future;
      return null;
    });
    await manager.openLoginAuth(requestId: 'first');
    var completed = false;
    final hiding = manager.setLoadingVisibility(false).then((_) {
      completed = true;
    });
    final call = await received.future;
    expect(call.method, 'setLoadingVisibility');
    expect(call.arguments, {'requestId': 'first', 'visibility': false});
    expect(completed, isFalse);

    // 原生命令已捕获旧编号，之后打开的新页不会被该命令借用。
    await manager.openLoginAuth(requestId: 'second');
    expect(call.arguments['requestId'], 'first');
    nativeCompleted.complete();
    await hiding;
    expect(completed, isTrue);
  });

  test('原生不支持显示 loading 的错误必须传播，不能伪造成功', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments['visibility'], isTrue);
      throw PlatformException(code: 'unsupported_operation');
    });
    await manager.openLoginAuth(requestId: 'active');
    await expectLater(
      manager.setLoadingVisibility(true),
      throwsA(isA<PlatformException>()
          .having((error) => error.code, 'code', 'unsupported_operation')),
    );
  });

  test('关页后的错误反馈不携带旧编号，原生页面失效错误会传播', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments['requestId'], isNull);
      throw PlatformException(code: 'auth_page_unavailable');
    });
    await manager.openLoginAuth(requestId: 'closed');
    await manager.finishAuthControllerCompletion();
    await expectLater(
      manager.showAuthError('不应显示在底层页面'),
      throwsA(isA<PlatformException>()
          .having((error) => error.code, 'code', 'auth_page_unavailable')),
    );
  });
}
