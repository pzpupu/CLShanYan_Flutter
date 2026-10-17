#import "ShanyanPlugin.h"
#import <CL_ShanYanSDK/CL_ShanYanSDK.h>
#import <AVFoundation/AVFoundation.h>
//Helpers
#import "CLShanYanCustomViewHelper.h"
#import "UIView+CLShanYanWidget.h"
#import "NSNumber+shanyanCategory.h"
#import "PlayerView.h"
#import "CLShanYanNativeStyle.h"

@interface ShanyanPlugin ()<CLShanYanSDKManagerDelegate>
@property (nonatomic,strong)id notifObserver;

@property(nonatomic,strong)NSObject<FlutterPluginRegistrar>*registrar;

@property(nonatomic,strong)FlutterMethodChannel* channel;

/// 样式快照按 SDK 授权页弱引用隔离；旧页面销毁后自动释放，不串用新请求配置。
@property(nonatomic,strong) NSMapTable<UIView *, NSDictionary *> *authPageStyles;

/// 原生命令与打开页面的编号绑定，不能操作另一轮授权页。
@property(nonatomic,copy) NSString *activeRequestId;
/// 仅持有当前页的非交互 toast；关闭或替换提示时立即移除，不持有待确认回执。
@property(nonatomic,strong) UIView *authErrorToast;
@end

@implementation ShanyanPlugin

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:_notifObserver];
    _notifObserver = nil;
}



+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"shanyan"
                                     binaryMessenger:[registrar messenger]];
    ShanyanPlugin* instance = [[ShanyanPlugin alloc] init];
    instance.channel = channel;
    instance.registrar = registrar;
    [registrar addMethodCallDelegate:instance channel:channel];
}

/// 引擎卸载不保留 toast 或已失效页面的命令入口。
- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    [ShanyanPlugin performMainBlock:^{
        self.activeRequestId = nil;
        [self clearAuthError];
        self.channel = nil;
    }];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"init" isEqualToString:call.method]){
        [self init:call complete:result];
    }else if ([@"getPhoneInfo" isEqualToString:call.method]){
        [self preGetPhonenumber:result];
    }else if ([@"openLoginAuth" isEqualToString:call.method]){
        [self quickAuthLoginWithConfigure:call.arguments complete:result];
    }else if ([@"setActionListener" isEqualToString:call.method]){
        [self setActionListener];
    }else if ([@"startAuthentication" isEqualToString:call.method]){
        [self startAuthentication:result];
    }else if ([@"finishAuthControllerCompletion" isEqualToString:call.method]){
        [self finishAuthControllerCompletion:result];
    }else if ([@"setLoadingVisibility" isEqualToString:call.method]){
        [self setLoadingVisibility:call complete:result];
    }else if ([@"showAuthError" isEqualToString:call.method]){
        [self showAuthError:call complete:result];
    }else if ([@"setCheckBoxValue" isEqualToString:call.method]){
        [self setCheckBoxValue:call];
    }else if ([@"clearScripCache" isEqualToString:call.method]){
        [self clearScripCache];
        result(nil);
    }else if ([@"performLoginClick" isEqualToString:call.method]){
        [self loginBtnClick];
    }else if ([@"setTimeOutForPreLogin" isEqualToString:call.method]){
        [self setPreGetPhonenumberTimeOut:call];
        result(nil);
    }else if ([@"setInitDebug" isEqualToString:call.method]){
        [self printConsoleEnable:call];
        result(nil);
    }else if ([@"getIEnable" isEqualToString:call.method]){
        [self getIEnable:call];
        result(nil);
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}


- (void)getIEnable:(FlutterMethodCall*)call{
    NSDictionary* argv = call.arguments;
    if (argv != nil && [argv isKindOfClass:[NSDictionary class]]) {
        [CLShanYanSDKManager forbiddenNonessentialIp:![argv[@"iEnable"] boolValue]];
    }
}

- (void)printConsoleEnable:(FlutterMethodCall*)call{
    NSDictionary* argv = call.arguments;
    if (argv != nil && [argv isKindOfClass:[NSDictionary class]]) {
        [CLShanYanSDKManager printConsoleEnable:[argv[@"initDebug"] boolValue]];
    }
}

- (void)setPreGetPhonenumberTimeOut:(FlutterMethodCall*)call{
    NSDictionary* argv = call.arguments;
    if (argv != nil && [argv isKindOfClass:[NSDictionary class]]) {
        [CLShanYanSDKManager setPreGetPhonenumberTimeOut:[argv[@"timeOut"] floatValue]];
    }
}

-(void)loginBtnClick {
    [CLShanYanSDKManager loginBtnClick];
}

- (void)clearScripCache {
    [CLShanYanSDKManager clearScripCache];
}

- (void)setCheckBoxValue:(FlutterMethodCall*)call{
    NSDictionary* argv = call.arguments;
    if (argv != nil && [argv isKindOfClass:[NSDictionary class]]) {
        [CLShanYanSDKManager setCheckBoxValue:[argv[@"isChecked"] boolValue]];
    }
}
/// 校验页面代际及 SDK 公开导航容器，不向 Flutter 底层页面展示业务错误。
- (UINavigationController *)authNavigationForCall:(FlutterMethodCall *)call
                                       complete:(FlutterResult)complete {
    NSString *requestId = call.arguments[@"requestId"];
    UINavigationController *navigation = [CLShanYanSDKManager authNavigationController];
    if (![requestId isKindOfClass:NSString.class] ||
        ![self.activeRequestId isEqualToString:requestId] ||
        !navigation.viewIfLoaded.window || navigation.isBeingDismissed) {
        complete([FlutterError errorWithCode:@"auth_page_unavailable"
                                    message:@"授权页已关闭或请求已失效"
                                    details:nil]);
        return nil;
    }
    return navigation;
}

/// iOS 2.3.7.7 只有公开 hideLoading；显示始终由 SDK 的有效按钮点击负责。
- (void)setLoadingVisibility:(FlutterMethodCall *)call complete:(FlutterResult)complete {
    [ShanyanPlugin performMainBlock:^{
        if (![self authNavigationForCall:call complete:complete]) {
            return;
        }
        if ([call.arguments[@"visibility"] boolValue]) {
            complete([FlutterError errorWithCode:@"unsupported_operation"
                                        message:@"iOS SDK 仅支持隐藏 loading，点击登录按钮会自动显示"
                                        details:nil]);
            return;
        }
        // 不再延迟 0.1 秒后查找全局页面；SDK 在此刻捕获当前页 view 后排队移除。
        [CLShanYanSDKManager hideLoading];
        // SDK 的移除动作已排在主队列，回执排在其后，调用方可顺序展示错误。
        dispatch_async(dispatch_get_main_queue(), ^{
            complete(nil);
        });
    }];
}

/// Toast 只占据消息所需空间，不创建模态控制器或拦截触摸，展示后立即回执。
- (void)showAuthError:(FlutterMethodCall *)call complete:(FlutterResult)complete {
    [ShanyanPlugin performMainBlock:^{
        UINavigationController *navigation = [self authNavigationForCall:call complete:complete];
        if (!navigation) {
            return;
        }
        UIViewController *presenter = navigation;
        while (presenter.presentedViewController) {
            presenter = presenter.presentedViewController;
        }
        if (!presenter.viewIfLoaded.window || presenter.isBeingDismissed) {
            complete([FlutterError errorWithCode:@"auth_page_unavailable"
                                        message:@"授权页正在关闭"
                                        details:nil]);
            return;
        }
        // 后一次错误替换前一次，不堆积消息，也不延迟用户的下一次点击。
        [self clearAuthError];
        UIView *host = presenter.view;
        UIView *toast = [[UIView alloc] init];
        toast.translatesAutoresizingMaskIntoConstraints = NO;
        toast.userInteractionEnabled = NO;
        toast.accessibilityElementsHidden = YES;
        toast.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.9];
        toast.layer.cornerRadius = 12;
        toast.clipsToBounds = YES;
        UILabel *label = [[UILabel alloc] init];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.text = call.arguments[@"message"];
        label.textColor = UIColor.systemBackgroundColor;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        label.adjustsFontForContentSizeCategory = YES;
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        [toast addSubview:label];
        [host addSubview:toast];
        // 只约束自有 toast，不修改 SDK 布局；安全区内多行排版，不覆盖整张页面。
        UILayoutGuide *safeArea = host.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [toast.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
            [toast.leadingAnchor constraintGreaterThanOrEqualToAnchor:safeArea.leadingAnchor constant:24],
            [toast.trailingAnchor constraintLessThanOrEqualToAnchor:safeArea.trailingAnchor constant:-24],
            [toast.widthAnchor constraintLessThanOrEqualToConstant:480],
            [toast.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-24],
            [label.leadingAnchor constraintEqualToAnchor:toast.leadingAnchor constant:16],
            [label.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-16],
            [label.topAnchor constraintEqualToAnchor:toast.topAnchor constant:12],
            [label.bottomAnchor constraintEqualToAnchor:toast.bottomAnchor constant:-12],
        ]];
        self.authErrorToast = toast;
        // 读屏只播报，不转移焦点或要求确认；普通触摸始终穿透 toast。
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, label.text);
        // 保留 5 秒供用户读完错误和重试指引，展示期间仍允许继续操作。
        __weak typeof(self) weakSelf = self;
        __weak UIView *weakToast = toast;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 已被替换或已关闭的旧提示不得移除下一张页面的新 toast。
            if (weakSelf.authErrorToast == weakToast) {
                [weakSelf clearAuthError];
            }
        });
        complete(nil);
    }];
}

/// 关页、取消和重复反馈共用清理路径；不等待消失动画或用户操作。
- (void)clearAuthError {
    [self.authErrorToast removeFromSuperview];
    self.authErrorToast = nil;
}

-(void)setActionListener{
    [CLShanYanSDKManager setCLShanYanSDKManagerDelegate:self];
}
#pragma mark - CLShanYanSDKManagerDelegate
-(void)clShanYanActionListener:(NSInteger)type code:(NSInteger)code  message:(NSString *_Nullable)message{
    NSMutableDictionary * result = [NSMutableDictionary dictionary];
    result[@"type"] = @(type);
    result[@"code"] = @(code);
    result[@"message"] = message;
    if (self.channel) {
        [ShanyanPlugin performMainBlock:^{
            [self.channel invokeMethod:@"onReceiveAuthEvent" arguments:result];
        }];
        
    }
}

/// 官方 ViewDidLoad 末尾回调：标准控件已经完成 SDK 自身的文字与外观设置。
- (void)clShanYanSDKManagerAuthPageCompleteViewDidLoad:(UIViewController *)authPageVC
                                      currentTelecom:(NSString *)telecom
                                              object:(NSObject *)object
                                            userInfo:(NSDictionary *)userInfo {
    [self applyNativeAuthStyleToViewController:authPageVC userInfo:userInfo];
}

/// 从协议页返回时重新应用同一页的快照，追加文案和阴影均保持幂等。
- (void)clShanYanSDKManagerAuthPageCompleteViewWillAppear:(UIViewController *)authPageVC
                                         currentTelecom:(NSString *)telecom
                                                 object:(NSObject *)object
                                               userInfo:(NSDictionary *)userInfo {
    [self applyNativeAuthStyleToViewController:authPageVC userInfo:userInfo];
}

/// 仅使用公开生命周期传入的真实控件，不读取私有属性或按显示文字扫描视图。
- (void)applyNativeAuthStyleToViewController:(UIViewController *)authPageVC
                                   userInfo:(NSDictionary *)userInfo {
    [ShanyanPlugin performMainBlock:^{
        NSDictionary *style = [self.authPageStyles objectForKey:authPageVC.view];
        if (!style) {
            return;
        }

        // SDK 2.3.7.7 的 ViewDidLoad/WillAppear 字典构造与 CFString 重定位证实这两个键。
        // sloganLabel 是真实运营商说明；shanYanSloganLabel 是闪验品牌说明，不能混用。
        UIButton *loginButton = userInfo[@"loginBtn"];
        if ([loginButton isKindOfClass:UIButton.class]) {
            NSNumber *elevation = style[@"setLogBtnElevation"];
            UIColor *shadowColor = style[@"setLogBtnShadowColor"];
            if (shadowColor) {
                loginButton.layer.shadowColor = shadowColor.CGColor;
            }
            if (elevation) {
                CGFloat height = MAX(0.0, elevation.doubleValue);
                loginButton.layer.shadowRadius = height;
                loginButton.layer.shadowOffset = CGSizeMake(0.0, height / 2.0);
                // ARGB 的透明度只留在 shadowColor 中，不再乘一次相同的 shadowOpacity。
                loginButton.layer.shadowOpacity = height > 0.0 ? (shadowColor ? 1.0f : 0.2f) : 0.0f;
                if (height > 0.0) {
                    // 保留按钮圆角，但允许阴影超出按钮边界；不更改父容器、触摸或协议行为。
                    loginButton.layer.masksToBounds = NO;
                }
                // 不缓存尚未布局完成的 bounds 为 shadowPath，让 UIKit 随按钮实际尺寸绘制。
            }
            [CLShanYanNativeStyle applyToButton:loginButton
                                  overlayColor:style[@"setLogBtnPressedOverlayColor"]
                                  pressedScale:style[@"setLogBtnPressedScale"]
                                      duration:style[@"setLogBtnAnimationDuration"]];
        }

        NSString *suffix = style[@"setSloganTextSuffix"];
        UILabel *sloganLabel = userInfo[@"sloganLabel"];
        if (suffix.length > 0 && [sloganLabel isKindOfClass:UILabel.class]) {
            NSString *operatorText = sloganLabel.text;
            if (operatorText.length > 0 && ![operatorText hasSuffix:suffix]) {
                sloganLabel.text = [operatorText stringByAppendingString:suffix];
            }
            // 说明原文不替换、不按运营商推断；使用现有标准布局宽高自然换行，不缩字。
            sloganLabel.numberOfLines = 0;
            sloganLabel.lineBreakMode = NSLineBreakByWordWrapping;
            sloganLabel.adjustsFontSizeToFitWidth = NO;
        }
    }];
}

/// 通过官方自定义区域回调绑定页级样式，避免异步旧页面拿到另一 requestId 的配置。
- (void)configureNativeAuthStyle:(CLUIConfigure *)configure options:(NSDictionary *)options {
    NSNumber *elevation = options[@"setLogBtnElevation"];
    if (![elevation isKindOfClass:NSNumber.class]) {
        elevation = nil;
    }
    UIColor *shadowColor = [ShanyanPlugin colorWithHexStr:options[@"setLogBtnShadowColor"]];
    NSString *suffix = options[@"setSloganTextSuffix"];
    if (![suffix isKindOfClass:NSString.class] || suffix.length == 0) {
        suffix = nil;
    }
    UIColor *overlayColor = [ShanyanPlugin colorWithHexStr:options[@"setLogBtnPressedOverlayColor"]];
    NSNumber *pressedScale = options[@"setLogBtnPressedScale"];
    NSNumber *duration = options[@"setLogBtnAnimationDuration"];
    if (![pressedScale isKindOfClass:NSNumber.class]) { pressedScale = nil; }
    if (![duration isKindOfClass:NSNumber.class]) { duration = nil; }
    // 缺省或显式 null 完全沿用 SDK 外观，不安装额外的样式生命周期状态。
    if (!elevation && !shadowColor && !suffix && !overlayColor && !pressedScale && !duration) {
        return;
    }
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithCapacity:6];
    if (elevation) {
        values[@"setLogBtnElevation"] = elevation;
    }
    if (shadowColor) {
        values[@"setLogBtnShadowColor"] = shadowColor;
    }
    if (suffix) {
        values[@"setSloganTextSuffix"] = suffix;
    }
    if (overlayColor) { values[@"setLogBtnPressedOverlayColor"] = overlayColor; }
    if (pressedScale) { values[@"setLogBtnPressedScale"] = pressedScale; }
    if (duration) { values[@"setLogBtnAnimationDuration"] = duration; }
    NSDictionary *style = [values copy];
    void (^customAreaViewBlock)(UIView *) = configure.customAreaView;
    __weak typeof(self) weakSelf = self;
    configure.customAreaView = ^(UIView *customAreaView) {
        // 当前 SDK 将 authPageVC.view 传给此公开回调，且先于 CompleteViewDidLoad 执行。
        [ShanyanPlugin performMainBlock:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf.authPageStyles) {
                strongSelf.authPageStyles = [NSMapTable weakToStrongObjectsMapTable];
            }
            [strongSelf.authPageStyles setObject:style forKey:customAreaView];
        }];
        if (customAreaViewBlock) {
            customAreaViewBlock(customAreaView);
        }
    };
}

- (void)init:(FlutterMethodCall*)call complete:(FlutterResult)complete{
    NSDictionary * argv = call.arguments;
    if (argv == nil || ![argv isKindOfClass:[NSDictionary class]]) {
        if (complete) {
            NSMutableDictionary * result = [NSMutableDictionary new];
            result[@"code"] = @(1001);
            result[@"message"] = @"请设置参数";
            complete(result);
        }
        return;
    }
    
    NSString * appId = argv[@"appId"];
    
    [CLShanYanSDKManager initWithAppId:appId complete:^(CLCompleteResult * _Nonnull completeResult) {
        
        if (complete) {
            [ShanyanPlugin performMainBlock:^{
                complete([ShanyanPlugin completeResultToJson:completeResult]);
            }];
        }
    }];
}

- (void)preGetPhonenumber:(FlutterResult)complete{
    
    [CLShanYanSDKManager preGetPhonenumber:^(CLCompleteResult * _Nonnull completeResult) {
        if (complete) {
            [ShanyanPlugin performMainBlock:^{
                complete([ShanyanPlugin completePhoneResultToJson:completeResult]);
            }];
        }
    }];
}

-(void)quickAuthLoginWithConfigure:(NSDictionary *)clUIConfigure complete:(FlutterResult)complete{
    // 捕获本次编号，关闭后的迟到回调由 Dart 桥接层拒绝。
    NSString *requestId = [clUIConfigure[@"requestId"] copy];
    self.activeRequestId = requestId;
    [self clearAuthError];
    
    CLUIConfigure * baseUIConfigure = [self configureWithConfig:clUIConfigure];
    baseUIConfigure.viewController = [self findVisibleVC];
    [self configureNativeAuthStyle:baseUIConfigure options:clUIConfigure];
    
    __weak typeof(self) weakSelf = self;
    
    [CLShanYanSDKManager setCLShanYanSDKManagerDelegate:self];
    [CLShanYanSDKManager quickAuthLoginWithConfigure:baseUIConfigure openLoginAuthListener:^(CLCompleteResult * _Nonnull completeResult) {
        if (complete) {
            [ShanyanPlugin performMainBlock:^{
                complete([ShanyanPlugin completeResultToJson:completeResult]);
            }];
        }
        
    } oneKeyLoginListener:^(CLCompleteResult * _Nonnull completeResult) {
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        //一键登录回调
        if (strongSelf.channel) {
            [ShanyanPlugin performMainBlock:^{
                NSMutableDictionary *event = [[ShanyanPlugin completeResultToJson:completeResult] mutableCopy];
                if (requestId != nil) {
                    event[@"requestId"] = requestId;
                }
                // 只清理当前页的取消事件；旧 SDK 回调不能关闭新页面的提示。
                if ([event[@"code"] integerValue] == 1011 &&
                    [strongSelf.activeRequestId isEqualToString:requestId]) {
                    strongSelf.activeRequestId = nil;
                    [strongSelf clearAuthError];
                }
                [strongSelf.channel invokeMethod:@"onReceiveAuthPageEvent" arguments:event];
            }];
            
        }
    }];
}

+(NSString * )dictToJson:(NSDictionary *)input{
    NSError *error = nil;
    NSData *jsonData = nil;
    if (!input) {
        return nil;
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [input enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *keyString = nil;
        NSString *valueString = nil;
        if ([key isKindOfClass:[NSString class]]) {
            keyString = key;
        }else{
            keyString = [NSString stringWithFormat:@"%@",key];
        }
        
        if ([obj isKindOfClass:[NSString class]]) {
            valueString = obj;
        }else{
            valueString = [NSString stringWithFormat:@"%@",obj];
        }
        
        [dict setObject:valueString forKey:keyString];
    }];
    jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if ([jsonData length] == 0 || error != nil) {
        return nil;
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
    
}

+ (UIFont *)fontWithSize:(NSNumber *)size blod:(NSNumber *)isBlod name:(NSString *)name{
    if (size == nil) {
        return nil;
    }
    //    NSString * fontName = @"PingFang-SC-Medium";
    //    if (name) {
    //        fontName = fontName;
    //    }
    BOOL blod = isBlod!=nil ? isBlod.boolValue : false;
    if (blod) {
        return [UIFont boldSystemFontOfSize:size.floatValue];
    }else{
        return [UIFont systemFontOfSize:size.floatValue];
    }
}

+ (UIColor *)colorWithHexStr:(NSString *)hexString {
    if (hexString == nil) {
        return nil;
    }
    if (![hexString isKindOfClass:NSString.class]) {
        return nil;
    }
    if (hexString.length == 0) {
        return nil;
    }
    @try {
        NSString *colorString = [[hexString stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
        CGFloat alpha, red, blue, green;
        switch ([colorString length]) {
            case 3: // #RGB
                alpha = 1.0f;
                red   = [self colorComponentFrom: colorString start: 0 length: 1];
                green = [self colorComponentFrom: colorString start: 1 length: 1];
                blue  = [self colorComponentFrom: colorString start: 2 length: 1];
                break;
            case 4: // #ARGB
                alpha = [self colorComponentFrom: colorString start: 0 length: 1];
                red   = [self colorComponentFrom: colorString start: 1 length: 1];
                green = [self colorComponentFrom: colorString start: 2 length: 1];
                blue  = [self colorComponentFrom: colorString start: 3 length: 1];
                break;
            case 6: // #RRGGBB
                alpha = 1.0f;
                red   = [self colorComponentFrom: colorString start: 0 length: 2];
                green = [self colorComponentFrom: colorString start: 2 length: 2];
                blue  = [self colorComponentFrom: colorString start: 4 length: 2];
                break;
            case 8: // #AARRGGBB
                alpha = [self colorComponentFrom: colorString start: 0 length: 2];
                red   = [self colorComponentFrom: colorString start: 2 length: 2];
                green = [self colorComponentFrom: colorString start: 4 length: 2];
                blue  = [self colorComponentFrom: colorString start: 6 length: 2];
                break;
            default:
                return nil;
                break;
        }
        return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    } @catch (NSException *exception) {
        return UIColor.whiteColor;
    }
}

+ (CGFloat)colorComponentFrom:(NSString *)string start:(NSUInteger)start length:(NSUInteger)length {
    NSString *substring = [string substringWithRange: NSMakeRange(start, length)];
    NSString *fullHex = length == 2 ? substring : [NSString stringWithFormat: @"%@%@", substring, substring];
    unsigned hexComponent;
    [[NSScanner scannerWithString: fullHex] scanHexInt: &hexComponent];
    return hexComponent / 255.0;
}


+(NSDictionary *)completePhoneResultToJson:(CLCompleteResult *)completeResult{
    NSMutableDictionary * result = [NSMutableDictionary new];
    if (completeResult.error != nil) {
        result[@"code"] = @(completeResult.code);
        result[@"message"] = completeResult.message;
        if (completeResult.innerCode != 0) {
            result[@"innerCode"] = @(completeResult.innerCode);
        }
        if ([completeResult.innerDesc isKindOfClass:NSString.class] && completeResult.innerDesc.length > 0) {
            result[@"innerDesc"] = completeResult.innerDesc;
        }
    }else{
        result[@"code"] = @(1000);
        result[@"message"] = completeResult.message;
        if (completeResult.innerCode != 0) {
            result[@"innerCode"] = @(completeResult.innerCode);
        }
        if ([completeResult.innerDesc isKindOfClass:NSString.class] && completeResult.innerDesc.length > 0) {
            result[@"innerDesc"] = completeResult.innerDesc;
        }
        if ([completeResult.data isKindOfClass:NSDictionary.class] && completeResult.data.count > 0) {
            result[@"protocolName"] = completeResult.data[@"protocolName"] ?: @"";
            result[@"telecom"] = completeResult.data[@"telecom"] ?: @"";
            result[@"number"] = completeResult.data[@"number"] ?: @"";
            result[@"protocolUrl"] = completeResult.data[@"protocolUrl"] ?: @"";
            result[@"slogan"] = completeResult.data[@"slogan"] ?: @"";
            result[@"clTokenFromType"] = completeResult.data[@"clTokenFromType"] ?: @"";
        }
    }
    return result;
}

/**
 *int code; //返回码
 String message; //描述
 String innerCode; //内层返回码
 String innerDesc; //内层事件描述
 String token; //token
 */
+(NSDictionary *)completeResultToJson:(CLCompleteResult *)completeResult{
    NSMutableDictionary * result = [NSMutableDictionary new];
    if (completeResult.error != nil) {
        result[@"code"] = @(completeResult.code);
        result[@"message"] = completeResult.message;
        if (completeResult.innerCode != 0) {
            result[@"innerCode"] = @(completeResult.innerCode);
        }
        if ([completeResult.innerDesc isKindOfClass:NSString.class] && completeResult.innerDesc.length > 0) {
            result[@"innerDesc"] = completeResult.innerDesc;
        }
    }else{
        result[@"code"] = @(1000);
        result[@"message"] = completeResult.message;
        if (completeResult.innerCode != 0) {
            result[@"innerCode"] = @(completeResult.innerCode);
        }
        if ([completeResult.innerDesc isKindOfClass:NSString.class] && completeResult.innerDesc.length > 0) {
            result[@"innerDesc"] = completeResult.innerDesc;
        }
        if ([completeResult.data isKindOfClass:NSDictionary.class] && completeResult.data.count > 0) {
            result[@"token"] = completeResult.data[@"token"];
        }
    }
    return result;
}

-(NSString * )assetPathWithConfig:(NSString *)configureDicPath{
    NSString * key = [self.registrar lookupKeyForAsset:configureDicPath];
    NSString * path = [[NSBundle mainBundle] pathForResource:key ofType:nil];
    if (path == nil) {
        path = @"";
    }
    return path;
}

-(CLUIConfigure *)configureWithConfig:(NSDictionary *)configureDic{
    CLUIConfigure * baseConfigure = [CLUIConfigure new];
    
    @try {
        NSNumber * isFinish = configureDic[@"isFinish"];
        {
            baseConfigure.manualDismiss = isFinish;
        }
        
        NSString * clBackgroundImg = configureDic[@"setAuthBGImgPath"];
        NSString * clBackgroundVedio = configureDic[@"setAuthBGVedioPath"];
        if (clBackgroundImg && (!clBackgroundVedio || clBackgroundVedio.length<1)) {
            baseConfigure.clBackgroundImg = [UIImage imageNamed:clBackgroundImg];
        }
        NSNumber * setPreferredStatusBarStyle = configureDic[@"setPreferredStatusBarStyle"];
        {
            if (setPreferredStatusBarStyle!=nil) {
                switch (setPreferredStatusBarStyle.intValue) {
                    case 0: default:
                        baseConfigure.clPreferredStatusBarStyle = @(UIStatusBarStyleDefault);
                        break;
                    case 1:
                        baseConfigure.clPreferredStatusBarStyle = @(UIStatusBarStyleLightContent);
                        break;
                    case 2:
                        if (@available(iOS 13.0, *)) {
                            baseConfigure.clPreferredStatusBarStyle = @(UIStatusBarStyleDarkContent);
                        }
                        break;
                }
            }
        };
        NSNumber * setStatusBarHidden = configureDic[@"setStatusBarHidden"];
        {
            baseConfigure.clPrefersStatusBarHidden = setStatusBarHidden;
        }
        NSNumber * setAuthNavHidden = configureDic[@"setAuthNavHidden"];
        {
            baseConfigure.clNavigationBarHidden = setAuthNavHidden;
        }
        NSNumber * setNavigationBarStyle = configureDic[@"setNavigationBarStyle"];
        {
            if (setNavigationBarStyle!=nil) {
                switch (setNavigationBarStyle.intValue) {
                    case 0: default:
                        baseConfigure.clNavigationBarStyle = @(UIBarStyleDefault);
                        break;
                    case 1:
                        baseConfigure.clNavigationBarStyle = @(UIBarStyleBlack);
                        break;
                }
            }
        };
        
        NSNumber * setAuthNavTransparent = configureDic[@"setAuthNavTransparent"];
        {
            baseConfigure.clNavigationBackgroundClear = setAuthNavTransparent;
        }
        
        NSString * setNavText = configureDic[@"setNavText"];
        NSString * setNavTextColor = configureDic[@"setNavTextColor"];
        NSNumber * setNavTextSize = configureDic[@"setNavTextSize"];
        if (setNavText) {
            NSMutableDictionary * attributes = [NSMutableDictionary dictionary];
            if (setNavTextColor != nil) {
                attributes[NSForegroundColorAttributeName] = [ShanyanPlugin colorWithHexStr:setNavTextColor];
            }
            if (setNavTextSize != nil) {
                attributes[NSFontAttributeName] = [UIFont systemFontOfSize:setNavTextSize.floatValue];
            }
            baseConfigure.clNavigationAttributesTitleText = [[NSAttributedString alloc]initWithString:setNavText attributes:attributes];
        }
        
        // UIBarButtonItem * clNavigationRightControl;
        // UIBarButtonItem * clNavigationLeftControl;
        
        NSString   * clNavigationBackBtnImage = configureDic[@"setNavReturnImgPath"];
        if (clNavigationBackBtnImage) {
            baseConfigure.clNavigationBackBtnImage = [UIImage imageNamed:clNavigationBackBtnImage];
        }
        
        NSNumber  * clNavigationBackBtnHidden = configureDic[@"setNavReturnImgHidden"];
        {
            baseConfigure.clNavigationBackBtnHidden = clNavigationBackBtnHidden;
        }
        // NSValue * clNavBackBtnImageInsets;
        NSNumber * clNavBackBtnAlimentRight = configureDic[@"setNavBackBtnAlimentRight"];
        {
            baseConfigure.clNavBackBtnAlimentRight = clNavBackBtnAlimentRight;
        };;
        NSNumber * clNavigationBottomLineHidden = configureDic[@"setNavigationBottomLineHidden"];
        {
            baseConfigure.clNavigationBottomLineHidden = clNavigationBottomLineHidden;
        }
        NSString  * clNavigationTintColor  = configureDic[@"setNavigationTintColor"];;
        {
            if (clNavigationTintColor ){ baseConfigure.clNavigationTintColor = [ShanyanPlugin colorWithHexStr:clNavigationTintColor];
            }
        };
        NSString  * clNavigationBarTintColor = configureDic[@"setNavigationBarTintColor"];;
        {
            if (clNavigationBarTintColor) {
                baseConfigure.clNavigationBarTintColor = [ShanyanPlugin colorWithHexStr:clNavigationBarTintColor];
            }
        };
        NSString  * clNavigationBackgroundImage = configureDic[@"setNavigationBackgroundImage"];
        if (clNavigationBackgroundImage) {
            baseConfigure.clNavigationBackgroundImage = [UIImage imageNamed:clNavigationBackgroundImage];
        }
        NSNumber * clNavigationBarMetrics = configureDic[@"setNavigationBarMetrics"];
        {
            baseConfigure.clNavigationBarMetrics = clNavigationBarMetrics;
        };
        NSString  * clNavigationShadowImage = configureDic[@"setNavigationShadowImage"];
        if (clNavigationShadowImage) {
            baseConfigure.clNavigationShadowImage = [UIImage imageNamed:clNavigationShadowImage];
        }
        
        /**Logo*/
        NSString * clLogoImage = configureDic[@"setLogoImgPath"];
        if (clLogoImage) {
            baseConfigure.clLogoImage = [UIImage imageNamed:clLogoImage];
        }
        NSNumber * clLogoCornerRadius = configureDic[@"setLogoCornerRadius"];
        {
            baseConfigure.clLogoCornerRadius = clLogoCornerRadius;
        };
        NSNumber * clLogoHiden  = configureDic[@"setLogoHidden"];
        {
            baseConfigure.clLogoHiden = clLogoHiden;
        };
        
        NSString  * clPhoneNumberColor  = configureDic[@"setNumberColor"];;
        {
            if (clPhoneNumberColor) {
                baseConfigure.clPhoneNumberColor = [ShanyanPlugin colorWithHexStr:clPhoneNumberColor];
            }
        };
        
        NSNumber   * clPhoneNumberFont = configureDic[@"setNumberSize"];
        NSNumber * setNumberBold = configureDic[@"setNumberBold"];
        {
            if (clPhoneNumberFont!=nil) {
                baseConfigure.clPhoneNumberFont = [ShanyanPlugin fontWithSize:clPhoneNumberFont blod:setNumberBold name:nil];
            }
        };
        // Dart 对齐枚举与 UIKit 共用原生值，不再交换 left/center。
        NSNumber *clPhoneNumberTextAlignment = configureDic[@"setNumberTextAlignment"];
        if (clPhoneNumberTextAlignment != nil) {
            baseConfigure.clPhoneNumberTextAlignment = clPhoneNumberTextAlignment;
        }
        
        /**按钮文字*/
        NSString   * clLoginBtnText = configureDic[@"setLogBtnText"];
        {
            baseConfigure.clLoginBtnText = clLoginBtnText;
        }
        /**按钮文字颜色*/
        NSString  * clLoginBtnTextColor = configureDic[@"setLogBtnTextColor"];;
        {
            if (clLoginBtnTextColor) {
                baseConfigure.clLoginBtnTextColor = [ShanyanPlugin colorWithHexStr:clLoginBtnTextColor];
            }
        }
        NSNumber   * setLoginBtnTextSize = configureDic[@"setLoginBtnTextSize"];
        NSNumber * setLoginBtnTextBold = configureDic[@"setLoginBtnTextBold"];
        {
            if (setLoginBtnTextSize!=nil) {
                baseConfigure.clLoginBtnTextFont = [ShanyanPlugin fontWithSize:setLoginBtnTextSize blod:setLoginBtnTextBold name:nil];
            }
        }
        /**按钮背景颜色*/
        NSString  * clLoginBtnBgColor = configureDic[@"setLoginBtnBgColor"];;
        {
            if (clLoginBtnBgColor) {
                baseConfigure.clLoginBtnBgColor = [ShanyanPlugin colorWithHexStr:clLoginBtnBgColor];
            }
        }
        
        /**按钮背景图片*/
        NSString  * clLoginBtnNormalBgImage = configureDic[@"setLoginBtnNormalBgImage"];
        if (clLoginBtnNormalBgImage) {
            baseConfigure.clLoginBtnNormalBgImage = [UIImage imageNamed:clLoginBtnNormalBgImage];
        }
        /**按钮背景高亮图片*/
        NSString  * clLoginBtnHightLightBgImage = configureDic[@"setLoginBtnHightLightBgImage"];
        if (clLoginBtnHightLightBgImage) {
            baseConfigure.clLoginBtnDisabledBgImage = [UIImage imageNamed:clLoginBtnHightLightBgImage];
        }
        /**按钮边框颜色*/
        NSString  * clLoginBtnBorderColor = configureDic[@"setLoginBtnBorderColor"];;
        {
            if (clLoginBtnBorderColor) {
                // 边框配置不能覆盖填充色，否则设置白色细边会把整个按钮改成白色。
                baseConfigure.clLoginBtnBorderColor = [ShanyanPlugin colorWithHexStr:clLoginBtnBorderColor];
            }
        };
        /**按钮圆角 CGFloat eg.@(5)*/
        NSNumber * clLoginBtnCornerRadius = configureDic[@"setLoginBtnCornerRadius"];
        {
            baseConfigure.clLoginBtnCornerRadius = clLoginBtnCornerRadius;
        }
        /**按钮边框 CGFloat eg.@(2.0)*/
        NSNumber * clLoginBtnBorderWidth = configureDic[@"setLoginBtnBorderWidth"];;
        {
            baseConfigure.clLoginBtnBorderWidth = clLoginBtnBorderWidth;
        }
        /*隐私条款Privacy
         注： 运营商隐私条款 不得隐藏
         用户条款不限制
         **/
        /**隐私条款名称颜色：@[基础文字颜色UIColor*,条款颜色UIColor*] eg.@[[UIColor lightGrayColor],[UIColor greenColor]]*/
        NSArray<NSString*> *clAppPrivacyColor = configureDic[@"setAppPrivacyColor"];
        {
            if (clAppPrivacyColor && clAppPrivacyColor.count == 2) {
                NSString * commomTextColors = clAppPrivacyColor.firstObject;
                NSString * appPrivacyColors = clAppPrivacyColor.lastObject;
                
                if (commomTextColors && appPrivacyColors) {
                    UIColor * commomTextColor = [ShanyanPlugin colorWithHexStr:commomTextColors];
                    UIColor * appPrivacyColor = [ShanyanPlugin colorWithHexStr:appPrivacyColors];
                    if (commomTextColor && appPrivacyColor) {
                        baseConfigure.clAppPrivacyColor = @[commomTextColor,appPrivacyColor];
                    }
                }
            }
        }
        /**隐私条款文字字体*/
        NSNumber   * setPrivacyTextSize = configureDic[@"setPrivacyTextSize"];
        NSNumber * setPrivacyTextBold = configureDic[@"setPrivacyTextBold"];
        {
            if (setPrivacyTextSize!=nil) {
                baseConfigure.clAppPrivacyTextFont = [ShanyanPlugin fontWithSize:setPrivacyTextSize blod:setPrivacyTextBold name:nil];
            }
        };
        // 协议与自定义文字采用同一 NSTextAlignment 契约，保留未配置时的 SDK 默认值。
        NSNumber *clAppPrivacyTextAlignment = configureDic[@"setAppPrivacyTextAlignment"];
        if (clAppPrivacyTextAlignment != nil) {
            baseConfigure.clAppPrivacyTextAlignment = clAppPrivacyTextAlignment;
        }
        /**运营商隐私条款书名号 默认NO 不显示 BOOL eg.@(YES)*/
        NSNumber * clAppPrivacyPunctuationMarks = configureDic[@"setPrivacySmhHidden"];;
        {
            baseConfigure.clAppPrivacyPunctuationMarks = clAppPrivacyPunctuationMarks;
        };
        /**多行时行距 CGFloat eg.@(2.0)*/
        NSNumber* clAppPrivacyLineSpacing = configureDic[@"setAppPrivacyLineSpacing"];;
        {
            baseConfigure.clAppPrivacyLineSpacing = clAppPrivacyLineSpacing;
        };
        //        NSNumber* clAppPrivacyLineFragmentPadding = configureDic[@"setAppPrivacyLineFragmentPadding"];
        //        {
        //            if (clAppPrivacyLineFragmentPadding) {
        //                baseConfigure.clAppPrivacyLineFragmentPadding = clAppPrivacyLineFragmentPadding;
        //            }
        //        }
        /**是否需要sizeToFit,设置后与宽高约束的冲突请自行考虑 BOOL eg.@(YES)*/
        NSNumber* clAppPrivacyNeedSizeToFit = configureDic[@"setAppPrivacyNeedSizeToFit"];;
        {
            baseConfigure.clAppPrivacyNeedSizeToFit = clAppPrivacyNeedSizeToFit;
        };
        /**隐私条款--APP名称简写 默认取CFBundledisplayname 设置描述文本四后此属性无效*/
        NSString  * clAppPrivacyAbbreviatedName = configureDic[@"setAppPrivacyAbbreviatedName"];;
        {
            baseConfigure.clAppPrivacyAbbreviatedName = clAppPrivacyAbbreviatedName;
        };
        /*
         *隐私条款Y一:需同时设置Name和UrlString eg.@[@"条款一名称",条款一URL]
         *@[NSSting,NSURL];
         */
        NSArray * clAppPrivacyFirst = configureDic[@"setAppPrivacyFirst"];
        {
            if (clAppPrivacyFirst && clAppPrivacyFirst.count == 2) {
                NSString * name = clAppPrivacyFirst.firstObject;
                NSString * url = clAppPrivacyFirst.lastObject;
                baseConfigure.clAppPrivacyFirst = @[name,[NSURL URLWithString:url]];
            }
        }
        /*
         *隐私条款二:需同时设置Name和UrlString eg.@[@"条款一名称",条款一URL]
         *@[NSSting,NSURL];
         */
        NSArray * clAppPrivacySecond = configureDic[@"setAppPrivacySecond"];
        {
            if (clAppPrivacySecond && clAppPrivacySecond.count == 2) {
                baseConfigure.clAppPrivacySecond = clAppPrivacySecond;
            }
        };
        /*
         *隐私条款三:需同时设置Name和UrlString eg.@[@"条款一名称",条款一URL]
         *@[NSSting,NSURL];
         */
        NSArray * clAppPrivacyThird = configureDic[@"setAppPrivacyThird"];
        {
            if (clAppPrivacyThird && clAppPrivacyThird.count == 2) {
                baseConfigure.clAppPrivacyThird = clAppPrivacyThird;
            }
        };
        
        
        /*
         隐私协议文本拼接: DesTextFirst+运营商条款+DesTextSecond+隐私条款一+DesTextThird+隐私条款二+DesTextFourth
         **/
        /**描述文本一 default:"同意"*/
        NSString *clAppPrivacyNormalDesTextFirst = configureDic[@"setAppPrivacyNormalDesTextFirst"];;
        {
            baseConfigure.clAppPrivacyNormalDesTextFirst = clAppPrivacyNormalDesTextFirst;
        };;
        /**描述文本二 default:"和"*/
        NSString *clAppPrivacyNormalDesTextSecond = configureDic[@"setAppPrivacyNormalDesTextSecond"];;
        {
            baseConfigure.clAppPrivacyNormalDesTextSecond = clAppPrivacyNormalDesTextSecond;
        };;
        /**描述文本三 default:"、"*/
        NSString *clAppPrivacyNormalDesTextThird = configureDic[@"setAppPrivacyNormalDesTextThird"];;
        {
            baseConfigure.clAppPrivacyNormalDesTextThird = clAppPrivacyNormalDesTextThird;
        };;
        /**描述文本四 default: "并授权AppName使用认证服务"*/
        NSString *clAppPrivacyNormalDesTextFourth = configureDic[@"setAppPrivacyNormalDesTextFourth"];;
        {
            baseConfigure.clAppPrivacyNormalDesTextFourth = clAppPrivacyNormalDesTextFourth;
        };
        
        NSString *clAppPrivacyNormalDesTextLast = configureDic[@"setAppPrivacyNormalDesTextLast"];;
        {
            baseConfigure.clAppPrivacyNormalDesTextLast = clAppPrivacyNormalDesTextLast;
        };
        
        NSNumber * setOperatorPrivacyAtLast = configureDic[@"setOperatorPrivacyAtLast"];
        {
            if (setOperatorPrivacyAtLast!=nil) {
                baseConfigure.clOperatorPrivacyAtLast = setOperatorPrivacyAtLast;
            }
        }
        
        NSArray * morePrivacyArr = configureDic[@"morePrivacy"];
        if(morePrivacyArr && morePrivacyArr.count>0) {
            NSMutableArray *priArr = [NSMutableArray arrayWithCapacity:0];
            for (NSDictionary *itemDic in morePrivacyArr) {
                NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:3];
                dic[@"decollator"] = itemDic[@"midStr"]?:@"";
                dic[@"privacyName"] = itemDic[@"name"]?:@"";
                dic[@"privacyURL"] = itemDic[@"url"]?:@"";
                [priArr addObject:dic];
            }
            baseConfigure.clAppMorePrivacyArray = priArr;
        }
        
        NSString *clCheckBoxTipMsg = configureDic[@"setCheckBoxTipMsg"];
        {
            baseConfigure.clCheckBoxTipMsg = clCheckBoxTipMsg;
        };
        NSNumber *setCheckBoxTipDisable = configureDic[@"setCheckBoxTipDisable"];;
        {
            baseConfigure.clCheckBoxTipDisable = setCheckBoxTipDisable;
        };
        
        /**用户隐私协议WEB页面导航栏标题 默认显示用户条款名称*/
        // NSAttributedString * clAppPrivacyWebAttributesTitle;
        /**运营商隐私协议WEB页面导航栏标题 默认显示运营商条款名称*/
        // NSAttributedString * clAppPrivacyWebNormalAttributesTitle;
        
        //        NSString * setPrivacyNavText = configureDic[@"setPrivacyNavText"];
        NSString * setPrivacyNavTextColor = configureDic[@"setPrivacyNavTextColor"];
        NSNumber * setPrivacyNavTextSize = configureDic[@"setPrivacyNavTextSize"];
        {
            NSMutableDictionary * attributes = [NSMutableDictionary dictionary];
            if (setPrivacyNavTextColor != nil) {
                attributes[NSForegroundColorAttributeName] = [ShanyanPlugin colorWithHexStr:setPrivacyNavTextColor];
            }
            if (setPrivacyNavTextSize != nil) {
                attributes[NSFontAttributeName] = [UIFont systemFontOfSize:setPrivacyNavTextSize.floatValue];
            }
            baseConfigure.clAppPrivacyWebAttributes = attributes;
        }
        
        
        /**隐私协议WEB页面导航返回按钮图片*/
        NSString * clAppPrivacyWebBackBtnImage = configureDic[@"setPrivacyNavReturnImgPath"];
        if (clAppPrivacyWebBackBtnImage) {
            baseConfigure.clAppPrivacyWebBackBtnImage = [UIImage imageNamed:clAppPrivacyWebBackBtnImage];
        }
        
        NSNumber * setAppPrivacyWebPreferredStatusBarStyle = configureDic[@"setAppPrivacyWebPreferredStatusBarStyle"];
        {
            if (setAppPrivacyWebPreferredStatusBarStyle!=nil) {
                if (setPreferredStatusBarStyle!=nil) {
                    switch (setPreferredStatusBarStyle.intValue) {
                        case 0: default:
                            baseConfigure.clAppPrivacyWebPreferredStatusBarStyle = @(UIStatusBarStyleDefault);
                            break;
                        case 1:
                            baseConfigure.clAppPrivacyWebPreferredStatusBarStyle = @(UIStatusBarStyleLightContent);
                            break;
                        case 2:
                            if (@available(iOS 13.0, *)) {
                                baseConfigure.clAppPrivacyWebPreferredStatusBarStyle = @(UIStatusBarStyleDarkContent);
                            }
                            break;
                    }
                }
            }
        }
        
        NSNumber * setAppPrivacyWebNavigationBarStyle = configureDic[@"setAppPrivacyWebNavigationBarStyle"];
        {
            if (setAppPrivacyWebNavigationBarStyle!=nil) {
                switch (setAppPrivacyWebNavigationBarStyle.intValue) {
                    case 0: default:
                        baseConfigure.clAppPrivacyWebNavigationBarStyle = @(UIBarStyleDefault);
                        break;
                    case 1:
                        baseConfigure.clAppPrivacyWebNavigationBarStyle = @(UIBarStyleBlack);
                        break;
                }
            }
        }
        
        NSString * setAppPrivacyWebNavigationTintColor = configureDic[@"setAppPrivacyWebNavigationTintColor"];
        {
            if (setAppPrivacyWebNavigationTintColor) {
                baseConfigure.clAppPrivacyWebNavigationTintColor = [ShanyanPlugin colorWithHexStr:setAppPrivacyWebNavigationTintColor];
            }
        }
        NSString * setAppPrivacyWebNavigationBarTintColor = configureDic[@"setAppPrivacyWebNavigationBarTintColor"];
        {
            if (setAppPrivacyWebNavigationBarTintColor) {
                baseConfigure.clAppPrivacyWebNavigationBarTintColor = [ShanyanPlugin colorWithHexStr:setAppPrivacyWebNavigationBarTintColor];
            }
        }
        NSString * setAppPrivacyWebNavigationBackgroundImage = configureDic[@"setAppPrivacyWebNavigationBackgroundImage"];
        if (setAppPrivacyWebNavigationBackgroundImage) {
            baseConfigure.clAppPrivacyWebNavigationBackgroundImage = [UIImage imageNamed:setAppPrivacyWebNavigationBackgroundImage];
        }
        NSString * setAppPrivacyWebNavigationShadowImage = configureDic[@"setAppPrivacyWebNavigationShadowImage"];
        if (setAppPrivacyWebNavigationShadowImage) {
            baseConfigure.clAppPrivacyWebNavigationShadowImage = [UIImage imageNamed:setAppPrivacyWebNavigationShadowImage];
        }
        
        /*SLOGAN
         注： 运营商品牌标签("中国**提供认证服务")，不得隐藏
         **/
        /**slogan文字字体*/
        NSNumber   * setSloganTextSize = configureDic[@"setSloganTextSize"];
        NSNumber * setSloganTextBold = configureDic[@"setSloganTextBold"];
        {
            if (setSloganTextSize!=nil) {
                baseConfigure.clSloganTextFont = [ShanyanPlugin fontWithSize:setSloganTextSize blod:setSloganTextBold name:nil];
            }
        };;
        /**slogan文字颜色*/
        NSString * clSloganTextColor = configureDic[@"setSloganTextColor"];;
        {
            if (clSloganTextColor) {
                baseConfigure.clSloganTextColor = [ShanyanPlugin colorWithHexStr:clSloganTextColor];
            }
        };
        // 运营商说明直接消费 UIKit 对齐值，避免标准控件与品牌文字方向相反。
        NSNumber *clSlogaTextAlignment = configureDic[@"setSloganTextAlignment"];
        if (clSlogaTextAlignment != nil) {
            baseConfigure.clSlogaTextAlignment = clSlogaTextAlignment;
        }
        
        NSNumber * setSloganTextHidden = configureDic[@"setSloganTextHidden"];
        {
            if (setSloganTextHidden!=nil) {
                baseConfigure.clSloganTextHidden = setSloganTextHidden;
            }
        }
        
        /*ShanyanSLOGAN
         注： 运营商品牌标签("创蓝253提供认证服务")，不得隐藏
         **/
        /**slogan文字字体*/
        NSNumber   * setShanYanSloganTextSize = configureDic[@"setShanYanSloganTextSize"];
        NSNumber * setShanYanSloganTextBold = configureDic[@"setShanYanSloganTextBold"];
        {
            if (setShanYanSloganTextSize!=nil) {
                baseConfigure.clShanYanSloganTextFont = [ShanyanPlugin fontWithSize:setShanYanSloganTextSize blod:setShanYanSloganTextBold name:nil];
            }
        };;
        /**slogan文字颜色*/
        NSString * setShanYanSloganTextColor = configureDic[@"setShanYanSloganTextColor"];
        {
            if (setShanYanSloganTextColor) {
                baseConfigure.clShanYanSloganTextColor = [ShanyanPlugin colorWithHexStr:clSloganTextColor];
            }
        };
        // 闪验说明沿用同一对齐枚举，不保留旧序号转换。
        NSNumber *setShanYanSlogaTextAlignment = configureDic[@"setShanYanSloganTextAlignment"];
        if (setShanYanSlogaTextAlignment != nil) {
            baseConfigure.clShanYanSloganTextAlignment = setShanYanSlogaTextAlignment;
        }
        
        NSNumber * setShanYanSloganHidden = configureDic[@"setShanYanSloganHidden"];
        {
            if (setShanYanSloganHidden!=nil) {
                baseConfigure.clShanYanSloganHidden = setShanYanSloganHidden;
            }
        }
        
        /*CheckBox
         *协议勾选框，默认选中且在协议前显示
         *可在sdk_oauth.bundle中替换checkBox_unSelected、checkBox_selected图片
         *也可以通过属性设置选中和未选择图片
         **/
        /**协议勾选框（默认显示,放置在协议之前）BOOL eg.@(YES)*/
        NSNumber *clCheckBoxHidden = configureDic[@"setCheckBoxHidden"];;
        {
            baseConfigure.clCheckBoxHidden = clCheckBoxHidden;
        };
        /**协议勾选框默认值（默认不选中）BOOL eg.@(YES)*/
        NSNumber *clCheckBoxValue = configureDic[@"setPrivacyState"];;
        {
            baseConfigure.clCheckBoxValue = clCheckBoxValue;
        };
        /**协议勾选框 尺寸 NSValue->CGSize eg.[NSValue valueWithCGSize:CGSizeMake(25, 25)]*/
        NSArray *clCheckBoxSize = configureDic[@"setCheckBoxWH"];
        {
            if (clCheckBoxSize && clCheckBoxSize.count == 2) {
                CGFloat width = [clCheckBoxSize.firstObject floatValue];
                CGFloat height = [clCheckBoxSize.lastObject floatValue];
                baseConfigure.clCheckBoxSize = [NSValue valueWithCGSize:CGSizeMake(width, height)];
            }
        }
        /**协议勾选框 UIButton.image图片缩进 UIEdgeInset eg.[NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(2, 2, 2, 2)]*/
        NSArray *clCheckBoxImageEdgeInsets = configureDic[@"setCheckBoxImageEdgeInsets"];
        {
            if (clCheckBoxImageEdgeInsets && clCheckBoxImageEdgeInsets.count == 4) {
                CGFloat top = [clCheckBoxImageEdgeInsets[0] floatValue];
                CGFloat left = [clCheckBoxImageEdgeInsets[1]  floatValue];
                CGFloat bottom = [clCheckBoxImageEdgeInsets[2]  floatValue];
                CGFloat right = [clCheckBoxImageEdgeInsets[3]  floatValue];
                baseConfigure.clCheckBoxImageEdgeInsets = [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(top, left, bottom, right)];
            }
        }
        /**协议勾选框 设置CheckBox顶部与隐私协议控件顶部对齐 YES或大于0生效 eg.@(YES)*/
        NSNumber *clCheckBoxVerticalAlignmentToAppPrivacyTop = configureDic[@"setCheckBoxVerticalAlignmentToAppPrivacyTop"];;
        {
            baseConfigure.clCheckBoxVerticalAlignmentToAppPrivacyTop = clCheckBoxVerticalAlignmentToAppPrivacyTop;
        };
        /**协议勾选框 设置CheckBox顶部与隐私协议控件竖向中心对齐 YES或大于0生效 eg.@(YES)*/
        NSNumber *clCheckBoxVerticalAlignmentToAppPrivacyCenterY = configureDic[@"setCheckBoxVerticalAlignmentToAppPrivacyCenterY"];
        {
            baseConfigure.clCheckBoxVerticalAlignmentToAppPrivacyCenterY = clCheckBoxVerticalAlignmentToAppPrivacyCenterY;
        };
        /**协议勾选框 非选中状态图片*/
        NSString  *clCheckBoxUncheckedImage = configureDic[@"setUncheckedImgPath"];
        if (clCheckBoxUncheckedImage) {
            baseConfigure.clCheckBoxUncheckedImage = [UIImage imageNamed:clCheckBoxUncheckedImage];
        }
        /**协议勾选框 选中状态图片*/
        NSString  *clCheckBoxCheckedImage = configureDic[@"setCheckedImgPath"];
        if (clCheckBoxCheckedImage) {
            baseConfigure.clCheckBoxCheckedImage = [UIImage imageNamed:clCheckBoxCheckedImage];
        }
        
        /*Loading*/
        /**Loading 大小 CGSize eg.[NSValue valueWithCGSize:CGSizeMake(50, 50)]*/
        NSArray *clLoadingSize = configureDic[@"setLoadingSize"];
        {
            if (clLoadingSize && clLoadingSize.count == 2) {
                CGFloat width = [clLoadingSize.firstObject floatValue];
                CGFloat height = [clLoadingSize.lastObject floatValue];
                baseConfigure.clLoadingSize = [NSValue valueWithCGSize:CGSizeMake(width, height)];
            }
        };
        /**Loading 圆角 float eg.@(5) */
        NSNumber *clLoadingCornerRadius = configureDic[@"setLoadingCornerRadius"];
        {
            baseConfigure.clLoadingCornerRadius = clLoadingCornerRadius;
        };
        /**Loading 背景色 UIColor eg.[UIColor colorWithRed:0.8 green:0.5 blue:0.8 alpha:0.8]; */
        NSString *clLoadingBackgroundColor = configureDic[@"setLoadingBackgroundColor"];
        {
            if (clLoadingBackgroundColor) {
                baseConfigure.clLoadingBackgroundColor = [ShanyanPlugin colorWithHexStr:clLoadingBackgroundColor];;
            }
        };
        /**UIActivityIndicatorViewStyle eg.@(UIActivityIndicatorViewStyleWhiteLarge)*/
        //    NSNumber *clLoadingIndicatorStyle = configureDic[@"clLoadingIndicatorStyle"];
        //    {
        //        baseConfigure.clLoadingIndicatorStyle = clLoadingIndicatorStyle;
        //    };
        baseConfigure.clLoadingIndicatorStyle = @(UIActivityIndicatorViewStyleWhite);
        
        /**Loading Indicator渲染色 UIColor eg.[UIColor greenColor]; */
        NSString *clLoadingTintColor = configureDic[@"setLoadingTintColor"];;
        {
            if (clLoadingTintColor) {
                baseConfigure.clLoadingTintColor = [ShanyanPlugin colorWithHexStr:clLoadingTintColor];
            }
        };
        
        /**横竖屏*/
        /*是否支持自动旋转 BOOL*/
        NSNumber * shouldAutorotate = configureDic[@"setShouldAutorotate"];
        {
            baseConfigure.shouldAutorotate = shouldAutorotate;
        };
        /*支持方向 UIInterfaceOrientationMask
         - 如果设置只支持竖屏，只需设置clOrientationLayOutPortrait竖屏布局对象
         - 如果设置只支持横屏，只需设置clOrientationLayOutLandscape横屏布局对象
         - 横竖屏均支持，需同时设置clOrientationLayOutPortrait和clOrientationLayOutLandscape
         */
        NSNumber * supportedInterfaceOrientations = configureDic[@"supportedInterfaceOrientations"];
        {
            /**支持方向
             * 0:UIInterfaceOrientationMaskPortrait
             * 1:UIInterfaceOrientationMaskLandscapeLeft
             * 2:UIInterfaceOrientationMaskLandscapeRight
             * 3:UIInterfaceOrientationMaskPortraitUpsideDown
             * 4:UIInterfaceOrientationMaskLandscape
             * 5:UIInterfaceOrientationMaskAll
             * 6:UIInterfaceOrientationMaskAllButUpsideDown
             * */
            if (supportedInterfaceOrientations!=nil) {
                switch (supportedInterfaceOrientations.integerValue) {
                    case 0:
                        baseConfigure.supportedInterfaceOrientations = @(UIInterfaceOrientationMaskPortrait);
                        break;
                    case 1:
                        baseConfigure.supportedInterfaceOrientations = @(UIInterfaceOrientationMaskLandscapeLeft);
                        break;
                    case 2:
                        baseConfigure.supportedInterfaceOrientations = @(UIInterfaceOrientationMaskLandscapeRight);
                        break;
                    case 3:
                        baseConfigure.supportedInterfaceOrientations = @(UIInterfaceOrientationMaskPortraitUpsideDown);
                        break;
                    case 4:
                        baseConfigure.supportedInterfaceOrientations = @(UIInterfaceOrientationMaskLandscape);
                        break;
                    case 5:
                        baseConfigure.supportedInterfaceOrientations = @(UIInterfaceOrientationMaskAll);
                        break;
                    case 6:
                        baseConfigure.supportedInterfaceOrientations = @(UIInterfaceOrientationMaskAllButUpsideDown);
                        break;
                    default:
                        break;
                }
            }
        };
        /*默认方向 UIInterfaceOrientation*/
        NSNumber * preferredInterfaceOrientationForPresentation = configureDic[@"preferredInterfaceOrientationForPresentation"];
        {
            /**偏好方向
             * -1:UIInterfaceOrientationUnknown
             * 0:UIInterfaceOrientationPortrait
             * 1:UIInterfaceOrientationPortraitUpsideDown
             * 2:UIInterfaceOrientationLandscapeLeft
             * 3:UIInterfaceOrientationLandscapeRight
             * */
            //偏好方向默认Portrait preferredInterfaceOrientationForPresentation: Number(5),
            if (preferredInterfaceOrientationForPresentation!=nil) {
                switch (preferredInterfaceOrientationForPresentation.integerValue) {
                    case 0:
                        baseConfigure.preferredInterfaceOrientationForPresentation = @(UIInterfaceOrientationPortrait);
                        break;
                    case 1:
                        baseConfigure.preferredInterfaceOrientationForPresentation = @(UIInterfaceOrientationPortraitUpsideDown);
                        break;
                    case 2:
                        baseConfigure.preferredInterfaceOrientationForPresentation = @(UIInterfaceOrientationLandscapeLeft);
                        break;
                    case 3:
                        baseConfigure.preferredInterfaceOrientationForPresentation = @(UIInterfaceOrientationLandscapeRight);
                        break;
                    default:
                        baseConfigure.preferredInterfaceOrientationForPresentation = @(UIInterfaceOrientationUnknown);
                        break;
                }
            }
        };
        
        /**以窗口方式显示授权页
         */
        /**以窗口方式显示 BOOL, default is NO */
        NSNumber * clAuthTypeUseWindow  = configureDic[@"setAuthTypeUseWindow"];
        {
            baseConfigure.clAuthTypeUseWindow = clAuthTypeUseWindow;
        };
        /**窗口圆角 float*/
        NSNumber * clAuthWindowCornerRadius = configureDic[@"setAuthWindowCornerRadius"];
        {
            baseConfigure.clAuthWindowCornerRadius = clAuthWindowCornerRadius;
        };
        
        /**clAuthWindowModalTransitionStyle系统自带的弹出方式 仅支持以下三种
         UIModalTransitionStyleCoverVertical 底部弹出
         UIModalTransitionStyleCrossDissolve 淡入
         UIModalTransitionStyleFlipHorizontal 翻转显示
         */
        NSNumber * clAuthWindowModalTransitionStyle = configureDic[@"setAuthWindowModalTransitionStyle"];
        {
            if (clAuthWindowModalTransitionStyle!=nil) {
                switch (clAuthWindowModalTransitionStyle.intValue) {
                    case 0: default:
                        baseConfigure.clAuthWindowModalTransitionStyle = @(UIModalTransitionStyleCoverVertical);
                        break;
                    case 1:
                        baseConfigure.clAuthWindowModalTransitionStyle = @(UIModalTransitionStyleFlipHorizontal);
                        break;
                    case 2:
                        baseConfigure.clAuthWindowModalTransitionStyle = @(UIModalTransitionStyleCrossDissolve);
                        break;
                }
            }
        };
        
        NSNumber * setAuthWindowModalPresentationStyle = configureDic[@"setAuthWindowModalPresentationStyle"];
        {
            if (setAuthWindowModalPresentationStyle!=nil) {
                switch (setAuthWindowModalPresentationStyle.intValue) {
                    case 0: default:
                        baseConfigure.clAuthWindowModalPresentationStyle = @(UIModalPresentationFullScreen);
                        break;
                    case 1:
                        baseConfigure.clAuthWindowModalPresentationStyle = @(UIModalPresentationOverFullScreen);
                        break;
                    case 2:
                        if (@available(iOS 13.0, *)) {
                            baseConfigure.clAuthWindowModalPresentationStyle = @(UIModalPresentationAutomatic);
                        }
                        break;
                }
            }
        };
        NSNumber * setAppPrivacyWebModalPresentationStyle = configureDic[@"setAppPrivacyWebModalPresentationStyle"];
        {
            if (setAppPrivacyWebModalPresentationStyle!=nil) {
                switch (setAppPrivacyWebModalPresentationStyle.intValue) {
                    case 0: default:
                        baseConfigure.clAppPrivacyWebModalPresentationStyle = @(UIModalPresentationFullScreen);
                        break;
                    case 1:
                        baseConfigure.clAppPrivacyWebModalPresentationStyle = @(UIModalPresentationOverFullScreen);
                        break;
                    case 2:
                        if (@available(iOS 13.0, *)) {
                            baseConfigure.clAppPrivacyWebModalPresentationStyle = @(UIModalPresentationAutomatic);
                        }
                        break;
                }
            }
        };
        
        NSNumber * setAuthWindowOverrideUserInterfaceStyle = configureDic[@"setAuthWindowOverrideUserInterfaceStyle"];
        {
            if (setAuthWindowOverrideUserInterfaceStyle!=nil) {
                if (@available(iOS 13.0, *)) {
                    switch (setAuthWindowOverrideUserInterfaceStyle.integerValue) {
                        case 0: default:
                            baseConfigure.clAuthWindowOverrideUserInterfaceStyle = @(UIUserInterfaceStyleUnspecified);
                            break;
                        case 1:
                            baseConfigure.clAuthWindowOverrideUserInterfaceStyle = @(UIUserInterfaceStyleLight);
                            break;
                        case 2:
                            baseConfigure.clAuthWindowOverrideUserInterfaceStyle = @(UIUserInterfaceStyleDark);
                            break;
                    }
                }
            }
        }
        
        NSNumber * setAuthWindowPresentingAnimate = configureDic[@"setAuthWindowPresentingAnimate"];
        {
            if (setAuthWindowPresentingAnimate!=nil) {
                baseConfigure.clAuthWindowPresentingAnimate = setAuthWindowPresentingAnimate;
            }
        }
        
        
        //自定义控件
        NSArray * clCustomViewArray = configureDic[@"widgets"];
        if (clCustomViewArray) {
            
            //导航栏控件
            for (NSDictionary * clCustomDict in clCustomViewArray) {
                // 装饰始终属于授权页背景，不占用导航栏入口。
                if ([clCustomDict[@"isBackground"] boolValue]) {
                    continue;
                }
                NSString * type = clCustomDict[@"type"];
                NSString * navPosition = clCustomDict[@"navPosition"];
                if ([navPosition isEqualToString:@"navleft"] || [navPosition isEqualToString:@"navright"]) {
                    //导航栏控件
                    
                    NSString * widgetId = clCustomDict[@"widgetId"];
                    NSNumber * isFinish = clCustomDict[@"isFinish"];
                    
                    CLShanYanCustomViewCongifure * customViewConfigure = [self customViewConfigureWithDict:clCustomDict];
                    
                    UIBarButtonItem * barButtonItem = [[UIBarButtonItem alloc]init];
                    
                    if ([type isEqualToString:@"TextView"]) {
                        
                        UILabel * customLabel = [CLShanYanCustomViewHelper customLabelWithCongifure:customViewConfigure];
                        
                        customLabel.widgetId = widgetId;
                        
                        NSNumber * clLayoutWidth = clCustomDict[@"width"];
                        NSNumber * clLayoutHeight = clCustomDict[@"height"];
                        
                        customLabel.frame = CGRectMake(0, 0, clLayoutWidth.floatValue, clLayoutHeight.floatValue);
                        
                        [barButtonItem setCustomView:customLabel];
                        
                    }else if ([type isEqualToString:@"ImageView"]){
                        
                        UIImageView * customImageView = [CLShanYanCustomViewHelper customImageViewWithCongifure:customViewConfigure];
                        
                        customImageView.widgetId = widgetId;
                        
                        NSNumber * clLayoutWidth = clCustomDict[@"width"];
                        NSNumber * clLayoutHeight = clCustomDict[@"height"];
                        
                        customImageView.frame = CGRectMake(0, 0, clLayoutWidth.floatValue, clLayoutHeight.floatValue);
                        
                        [barButtonItem setCustomView:customImageView];
                        
                    }else if ([type isEqualToString:@"Button"]){
                        
                        UIButton * custonButton = [CLShanYanCustomViewHelper customButtonWithCongifure:customViewConfigure];
                        
                        custonButton.widgetId = widgetId;
                        custonButton.isFinish = isFinish.boolValue;
                        
                        [custonButton addTarget:self action:@selector(customButtonClicked:) forControlEvents:(UIControlEventTouchUpInside)];
                        
                        NSNumber * clLayoutWidth = clCustomDict[@"width"];
                        NSNumber * clLayoutHeight = clCustomDict[@"height"];
                        
                        custonButton.frame = CGRectMake(0, 0, clLayoutWidth.floatValue, clLayoutHeight.floatValue);
                        
                        [barButtonItem setCustomView:custonButton];
                    }
                    
                    if (barButtonItem.customView) {
                        [ShanyanPlugin applyCustomTextStyleToView:barButtonItem.customView options:clCustomDict];
                        if ([navPosition isEqualToString:@"navleft"]) {
                            baseConfigure.clNavigationLeftControl = barButtonItem;
                        }
                        if ([navPosition isEqualToString:@"navright"]) {
                            baseConfigure.clNavigationRightControl = barButtonItem;
                        }
                    }
                    
                }
            }
            
            //授权页自定义控件
            __weak typeof(self)weakSelf = self;
            // 捕获配置中的同一张图片，识别 SDK 背景时不依赖号码、文案或私有类名。
            UIImage *authBackgroundImage = baseConfigure.clBackgroundImg;
            baseConfigure.customAreaView = ^(UIView * _Nonnull customAreaView) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    UIView *backgroundContainer = customAreaView;
                    UIImageView *backgroundImageView = [ShanyanPlugin backgroundImageViewInView:customAreaView image:authBackgroundImage];
                    if (!backgroundImageView && customAreaView.superview) {
                        backgroundImageView = [ShanyanPlugin backgroundImageViewInView:customAreaView.superview image:authBackgroundImage];
                        if (backgroundImageView) {
                            backgroundContainer = customAreaView.superview;
                        }
                    }
                    // 仅插入装饰自身，不挪动 customAreaView 或 SDK 的任何标准控件。
                    NSUInteger backgroundIndex = backgroundImageView
                        ? [backgroundContainer.subviews indexOfObjectIdenticalTo:backgroundImageView] + 1
                        : 0;
                    for (NSDictionary * clCustomDict in clCustomViewArray) {
                        
                        NSString * type = clCustomDict[@"type"];
                        NSString * navPosition = clCustomDict[@"navPosition"];
                        BOOL isBackground = [clCustomDict[@"isBackground"] boolValue];
                        if (!isBackground && ([navPosition isEqualToString:@"navleft"] || [navPosition isEqualToString:@"navright"])) {
                            //导航栏控件跳过
                            continue;
                        }
                        NSString * widgetId = clCustomDict[@"widgetId"];
                        NSNumber * isFinish = clCustomDict[@"isFinish"];
                        
                        CLShanYanCustomViewCongifure * customViewConfigure = [strongSelf customViewConfigureWithDict:clCustomDict];
                        
                        UIView *customView = nil;
                        if ([type isEqualToString:@"TextView"]) {
                            customView = [CLShanYanCustomViewHelper customLabelWithCongifure:customViewConfigure];
                        } else if ([type isEqualToString:@"ImageView"]) {
                            customView = [CLShanYanCustomViewHelper customImageViewWithCongifure:customViewConfigure];
                        } else if ([type isEqualToString:@"Button"]) {
                            UIButton *customButton = [CLShanYanCustomViewHelper customButtonWithCongifure:customViewConfigure];
                            if (!isBackground) {
                                customButton.isFinish = isFinish.boolValue;
                                [customButton addTarget:strongSelf action:@selector(customButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
                            }
                            customView = customButton;
                        }
                        if (!customView) {
                            continue;
                        }
                        [ShanyanPlugin applyCustomTextStyleToView:customView options:clCustomDict];
                        customView = [ShanyanPlugin applyDecorationShadowToView:customView options:clCustomDict];
                        customView.widgetId = widgetId;
                        if (isBackground) {
                            customView.userInteractionEnabled = NO;
                            customView.isAccessibilityElement = NO;
                            customView.accessibilityElementsHidden = YES;
                            // 在背景图上方按声明顺序叠放，避免白卡被不透明背景图盖住。
                            [backgroundContainer insertSubview:customView atIndex:backgroundIndex++];
                        } else {
                            [customAreaView addSubview:customView];
                        }
                        // 即使装饰与 customAreaView 同级，约束仍沿用官方区域的坐标。
                        [ShanyanPlugin setConstraint:customAreaView targetView:customView contrains:clCustomDict];
                    }
                    NSString *clBackgroundVedio = configureDic[@"setAuthBGVedioPath"];
                    if (clBackgroundVedio) {
                        NSString *path = [[NSBundle mainBundle] pathForResource:clBackgroundVedio ofType:@"mp4"];
                        if (path) {
                            NSURL *url = [NSURL fileURLWithPath:path];
                            if (url) {
                                PlayerView *playerView = [[PlayerView alloc] init];
                                [customAreaView addSubview:playerView];
                                playerView.translatesAutoresizingMaskIntoConstraints = NO;
                                NSLayoutConstraint * left = [NSLayoutConstraint constraintWithItem:playerView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:customAreaView attribute:NSLayoutAttributeLeft multiplier:1.0f constant:0.];
                                left.active = YES;
                                NSLayoutConstraint * top = [NSLayoutConstraint constraintWithItem:playerView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:customAreaView attribute:NSLayoutAttributeTop multiplier:1.0f constant:0.];
                                top.active = YES;
                                NSLayoutConstraint * right = [NSLayoutConstraint constraintWithItem:playerView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:customAreaView attribute:NSLayoutAttributeRight multiplier:1.0f constant:0.];
                                right.active = YES;
                                NSLayoutConstraint * bottom = [NSLayoutConstraint constraintWithItem:playerView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:customAreaView attribute:NSLayoutAttributeBottom multiplier:1.0f constant:0.];
                                bottom.active = YES;
                                [customAreaView updateConstraintsIfNeeded];
                                [customAreaView sendSubviewToBack:playerView];
                                
                                AVPlayerItem *playeItem = [[AVPlayerItem alloc] initWithURL:url];
                                AVPlayer *player = [AVPlayer playerWithPlayerItem:playeItem];
                                
                                AVPlayerLayer *playerLayer = (AVPlayerLayer *)playerView.layer;
                                playerLayer.player = player;
                                playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                                [player play];
                                [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull note) {
                                    CMTime time  = CMTimeMake(0, 1);
                                    [player seekToTime:time];
                                    [player play];
                                }];
                                [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull note) {
                                    if(player) [player pause];
                                }];
                                [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull note) {
                                    if(player) [player play];
                                }];
                            }
                        }
                        
                    }
                });
            };
        }
        
        /**弹窗的MaskLayer，用于自定义窗口形状*/
        // CALayer * clAuthWindowMaskLayer;
        
        NSDictionary * clOrientationLayOutPortraitDict = configureDic[@"layOutPortrait"];
        NSDictionary * clOrientationLayOutLandscapeDict = configureDic[@"layOutLandscape"];
        
        if (clOrientationLayOutPortraitDict.count > 0) {
            CLOrientationLayOut * clOrientationLayOutPortrait = [self clOrientationLayOutWithConfigure:clOrientationLayOutPortraitDict];
            baseConfigure.clOrientationLayOutPortrait = clOrientationLayOutPortrait;
        }
        if (clOrientationLayOutLandscapeDict.count > 0) {
            CLOrientationLayOut * clOrientationLayOutLandscape = [self clOrientationLayOutWithConfigure:clOrientationLayOutLandscapeDict];
            baseConfigure.clOrientationLayOutLandscape = clOrientationLayOutLandscape;
        }
    } @catch (NSException *exception) {
        NSLog(@"%@",exception.userInfo);
    }
    return baseConfigure;
}

/// 仅在官方自定义区域及其直属父视图中识别本次配置的背景图片。
/// 不遍历业务控件、不查询私有属性，也不通过用户号码或文案判断视图用途。
+ (UIImageView *)backgroundImageViewInView:(UIView *)view image:(UIImage *)image {
    if (!image) {
        return nil;
    }
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:UIImageView.class]) {
            UIImageView *imageView = (UIImageView *)subview;
            UIImage *candidate = imageView.image;
            if (candidate == image ||
                (candidate.CGImage && candidate.CGImage == image.CGImage)) {
                return imageView;
            }
        }
    }
    return nil;
}

//自定义控件事件
-(void)customButtonClicked:(UIButton *)sender{
    
    NSMutableDictionary * result = [NSMutableDictionary new];
    result[@"widgetId"] = sender.widgetId;
    result[@"isFinish"] = @(sender.isFinish);
    if (self.channel) {
        [ShanyanPlugin performMainBlock:^{
            [self.channel invokeMethod:@"onReceiveClickWidgetEvent" arguments:result];
        }];
    }
    
    
    if (sender.isFinish) {
        [self finishAuthControllerCompletion:nil];
    }
}

/// 统一自定义文字和按钮状态反馈；字号仍是 iOS 点值，不猜默认字体大小。
+ (void)applyCustomTextStyleToView:(UIView *)view options:(NSDictionary *)options {
    UILabel *label = nil;
    if ([view isKindOfClass:UIButton.class]) {
        label = ((UIButton *)view).titleLabel;
        // 反馈只追加公开 UIControl 事件，不移除原自定义按钮的点击与 isFinish 处理。
        UIColor *overlayColor = [ShanyanPlugin colorWithHexStr:options[@"pressedOverlayColor"]];
        NSNumber *pressedScale = options[@"pressedScale"];
        NSNumber *duration = options[@"animationDuration"];
        [CLShanYanNativeStyle applyToButton:(UIButton *)view
                              overlayColor:overlayColor
                              pressedScale:[pressedScale isKindOfClass:NSNumber.class] ? pressedScale : nil
                                  duration:[duration isKindOfClass:NSNumber.class] ? duration : nil];
    } else if ([view isKindOfClass:UILabel.class]) {
        label = (UILabel *)view;
    }
    if (!label) {
        return;
    }
    NSNumber *size = options[@"textFont"];
    NSNumber *bold = options[@"textBold"];
    if (![size isKindOfClass:NSNumber.class]) {
        size = nil;
    }
    if (![bold isKindOfClass:NSNumber.class]) {
        bold = nil;
    }
    // 两项都省略时不覆盖 UIKit 默认字体；false 明确恢复正常字重，null 沿用旧默认。
    if (size || bold) {
        label.font = [ShanyanPlugin fontWithSize:size ?: @(label.font.pointSize) blod:bold name:nil];
    }
}

/// 仅为声明为背景的插件装饰绘制阴影；包装后的 frame 保持卡片本体，不挪动 SDK 控件。
+ (UIView *)applyDecorationShadowToView:(UIView *)view options:(NSDictionary *)options {
    if (![options[@"isBackground"] boolValue]) {
        return view;
    }
    UIColor *color = [ShanyanPlugin colorWithHexStr:options[@"shadowColor"]];
    if (!color) {
        return view;
    }
    NSArray *offset = options[@"shadowOffset"];
    CGSize shadowOffset = CGSizeZero;
    if ([offset isKindOfClass:NSArray.class] && offset.count == 2) {
        shadowOffset = CGSizeMake([offset[0] doubleValue], [offset[1] doubleValue]);
    }
    NSNumber *blurRadius = options[@"shadowBlurRadius"];
    NSNumber *spreadRadius = options[@"shadowSpreadRadius"];
    return [CLShanYanNativeStyle decorationWithContent:view shadowColor:color
                                          blurRadius:[blurRadius isKindOfClass:NSNumber.class] ? blurRadius.doubleValue : 0.0
                                        spreadRadius:[spreadRadius isKindOfClass:NSNumber.class] ? spreadRadius.doubleValue : 0.0
                                              offset:shadowOffset
                                        cornerRadius:view.layer.cornerRadius];
}

-(CLShanYanCustomViewCongifure *)customViewConfigureWithDict:(NSDictionary *)clCustomDict{
    
    if (clCustomDict == nil) {
        return nil;
    }
    
    @try {
        CLShanYanCustomViewCongifure * customViewConfigure = [[CLShanYanCustomViewCongifure alloc]init];
        
        //    NSString * widgetId = clCustomDict[@"widgetId"];
        ////    customViewConfigure.widgetId = widgetId;
        //
        //    NSNumber * isFinish = clCustomDict[@"isFinish"];
        //    if (isFinish) {
        ////        customViewConfigure.isFinish = isFinish.boolValue;
        //    }
        
        /**文字颜色*/
        UIColor  * clTextColor = [ShanyanPlugin colorWithHexStr:clCustomDict[@"textColor"]];
        if (clTextColor) {
            customViewConfigure.button_textColor = clTextColor;
            customViewConfigure.label_textColor = clTextColor;
        }
        NSString * textContent = clCustomDict[@"textContent"];
        if (textContent) {
            customViewConfigure.button_textContent = textContent;
            customViewConfigure.label_text = textContent;
        }
        
        NSNumber * numberOfLines = clCustomDict[@"numberOfLines"];
        if (numberOfLines != nil) {
            customViewConfigure.button_numberOfLines = numberOfLines;
            customViewConfigure.label_numberOfLines = numberOfLines;
        }

        // 仅 UIButton 消费此字段，顺序遵循共享契约 [left, top, right, bottom]。
        NSArray *contentPadding = clCustomDict[@"contentPadding"];
        if ([contentPadding isKindOfClass:NSArray.class] && contentPadding.count == 4) {
            customViewConfigure.button_contentEdgeInsets = [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(
                [contentPadding[1] doubleValue], [contentPadding[0] doubleValue],
                [contentPadding[3] doubleValue], [contentPadding[2] doubleValue])];
        }
        
        NSString * clButtonImage = clCustomDict[@"image"];
        if (clButtonImage) {
            //UIButton
            customViewConfigure.button_image = [UIImage imageNamed:clButtonImage];
            //UIImageView
            customViewConfigure.imageView_image = [UIImage imageNamed:clButtonImage];
        }
        
        
        NSString * clButtonBackgroundImage = clCustomDict[@"backgroundImgPath"];
        if (clButtonBackgroundImage) {
            customViewConfigure.button_backgroundImage = [UIImage imageNamed:clButtonBackgroundImage];
        }
        
        
        //UIView通用
        UIColor * backgroundColor = [ShanyanPlugin colorWithHexStr: clCustomDict[@"backgroundColor"]];
        if (backgroundColor) {
            customViewConfigure.backgroundColor = backgroundColor;
        }
        
        //UILabel
        NSNumber * textAlignment = clCustomDict[@"textAlignment"];
        if (textAlignment!=nil) {
            customViewConfigure.label_textAlignment = textAlignment;
        }
        
        //CALayer通用
        NSNumber * cornerRadius = clCustomDict[@"cornerRadius"];
        //            NSNumber * masksToBounds =  clCustomDict[@"masksToBounds"];
        if (cornerRadius!=nil) {
            customViewConfigure.layer_cornerRadius = cornerRadius;
            customViewConfigure.layer_masksToBounds = @(YES);
        }
        UIColor * borderColor = [ShanyanPlugin colorWithHexStr:clCustomDict[@"borderColor"]];
        if (borderColor) {
            customViewConfigure.layer_borderColor = borderColor;
            customViewConfigure.layer_masksToBounds = @(YES);
        }
        
        NSNumber * borderWidth = clCustomDict[@"borderWidth"];
        if (borderWidth!=nil) {
            customViewConfigure.layer_borderWidth = borderWidth;
            customViewConfigure.layer_masksToBounds = @(YES);
        }
        
        
        
        return customViewConfigure;
    } @catch (NSException *exception) {
        
    }
}


+(void)setConstraint:(UIView * )superView targetView:(UIView *)subView contrains:(NSDictionary * )dict{
    
    @try {
        NSNumber * clLayoutLeft = dict[@"left"];
        NSNumber * clLayoutTop = dict[@"top"];
        NSNumber * clLayoutRight = dict[@"right"];
        NSNumber * clLayoutBottom = dict[@"bottom"];
        NSNumber * clLayoutWidth = dict[@"width"];
        NSNumber * clLayoutHeight = dict[@"height"];
        NSNumber * clLayoutCenterX = dict[@"centerX"];
        NSNumber * clLayoutCenterY = dict[@"centerY"];
        
        subView.translatesAutoresizingMaskIntoConstraints = NO;
        
        if (clLayoutWidth != nil) {
            NSLayoutConstraint * c = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:clLayoutWidth.floatValue];
            c.active = YES;
        }
        
        if (clLayoutHeight != nil) {
            NSLayoutConstraint * c = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:clLayoutHeight.floatValue];
            c.active = YES;
        }
        
        if (clLayoutLeft != nil) {
            NSLayoutConstraint * c = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeLeft multiplier:1.0f constant:clLayoutLeft.floatValue];
            c.active = YES;
        }
        
        if (clLayoutTop != nil) {
            NSLayoutConstraint * c = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeTop multiplier:1.0f constant:clLayoutTop.floatValue];
            c.active = YES;
        }
        
        if (clLayoutRight != nil) {
            NSLayoutConstraint * c = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeRight multiplier:1.0f constant:clLayoutRight.clShanYanNegative.floatValue];
            c.active = YES;
        }
        
        if (clLayoutBottom != nil) {
            NSLayoutConstraint * c = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeBottom multiplier:1.0f constant:clLayoutBottom.clShanYanNegative.floatValue];
            c.active = YES;
        }
        
        if (clLayoutCenterX != nil) {
            NSLayoutConstraint * c = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:clLayoutCenterX.floatValue];
            c.active = YES;
        }
        
        if (clLayoutCenterY != nil) {
            NSLayoutConstraint * c = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:clLayoutCenterY.floatValue];
            c.active = YES;
        }
        
        [superView updateConstraintsIfNeeded];
    } @catch (NSException *exception) {
        
    }
}


/// 横竖屏共用 Dart 公开字段契约，不维护另一套 clLayout 前缀的字典键。
-(CLOrientationLayOut *)clOrientationLayOutWithConfigure:(NSDictionary *)layout {
    if (layout == nil) {
        return CLOrientationLayOut.clDefaultOrientationLayOut;
    }
    CLOrientationLayOut *result = [CLOrientationLayOut new];

    // 所有位置相对 SDK 授权页，右侧和底部沿用官方负向约束语义。
    result.clLayoutLogoLeft = layout[@"setLogoLeft"];
    result.clLayoutLogoTop = layout[@"setLogoTop"];
    result.clLayoutLogoRight = [layout[@"setLogoRight"] clShanYanNegative];
    result.clLayoutLogoBottom = [layout[@"setLogoBottom"] clShanYanNegative];
    result.clLayoutLogoWidth = layout[@"setLogoWidth"];
    result.clLayoutLogoHeight = layout[@"setLogoHeight"];
    result.clLayoutLogoCenterX = layout[@"setLogoCenterX"];
    result.clLayoutLogoCenterY = layout[@"setLogoCenterY"];

    result.clLayoutPhoneLeft = layout[@"setNumFieldLeft"];
    result.clLayoutPhoneTop = layout[@"setNumFieldTop"];
    result.clLayoutPhoneRight = [layout[@"setNumFieldRight"] clShanYanNegative];
    result.clLayoutPhoneBottom = [layout[@"setNumFieldBottom"] clShanYanNegative];
    result.clLayoutPhoneWidth = layout[@"setNumFieldWidth"];
    result.clLayoutPhoneHeight = layout[@"setNumFieldHeight"];
    result.clLayoutPhoneCenterX = layout[@"setNumFieldCenterX"];
    result.clLayoutPhoneCenterY = layout[@"setNumFieldCenterY"];

    result.clLayoutLoginBtnLeft = layout[@"setLogBtnLeft"];
    result.clLayoutLoginBtnTop = layout[@"setLogBtnTop"];
    result.clLayoutLoginBtnRight = [layout[@"setLogBtnRight"] clShanYanNegative];
    result.clLayoutLoginBtnBottom = [layout[@"setLogBtnBottom"] clShanYanNegative];
    result.clLayoutLoginBtnWidth = layout[@"setLogBtnWidth"];
    result.clLayoutLoginBtnHeight = layout[@"setLogBtnHeight"];
    result.clLayoutLoginBtnCenterX = layout[@"setLogBtnCenterX"];
    result.clLayoutLoginBtnCenterY = layout[@"setLogBtnCenterY"];

    result.clLayoutAppPrivacyLeft = layout[@"setPrivacyLeft"];
    result.clLayoutAppPrivacyTop = layout[@"setPrivacyTop"];
    result.clLayoutAppPrivacyRight = [layout[@"setPrivacyRight"] clShanYanNegative];
    result.clLayoutAppPrivacyBottom = [layout[@"setPrivacyBottom"] clShanYanNegative];
    result.clLayoutAppPrivacyWidth = layout[@"setPrivacyWidth"];
    result.clLayoutAppPrivacyHeight = layout[@"setPrivacyHeight"];
    result.clLayoutAppPrivacyCenterX = layout[@"setPrivacyCenterX"];
    result.clLayoutAppPrivacyCenterY = layout[@"setPrivacyCenterY"];

    result.clLayoutSloganLeft = layout[@"setSloganLeft"];
    result.clLayoutSloganTop = layout[@"setSloganTop"];
    result.clLayoutSloganRight = [layout[@"setSloganRight"] clShanYanNegative];
    result.clLayoutSloganBottom = [layout[@"setSloganBottom"] clShanYanNegative];
    result.clLayoutSloganWidth = layout[@"setSloganWidth"];
    result.clLayoutSloganHeight = layout[@"setSloganHeight"];
    result.clLayoutSloganCenterX = layout[@"setSloganCenterX"];
    result.clLayoutSloganCenterY = layout[@"setSloganCenterY"];

    result.clLayoutShanYanSloganLeft = layout[@"setShanYanSloganLeft"];
    result.clLayoutShanYanSloganTop = layout[@"setShanYanSloganTop"];
    result.clLayoutShanYanSloganRight = [layout[@"setShanYanSloganRight"] clShanYanNegative];
    result.clLayoutShanYanSloganBottom = [layout[@"setShanYanSloganBottom"] clShanYanNegative];
    result.clLayoutShanYanSloganWidth = layout[@"setShanYanSloganWidth"];
    result.clLayoutShanYanSloganHeight = layout[@"setShanYanSloganHeight"];
    result.clLayoutShanYanSloganCenterX = layout[@"setShanYanSloganCenterX"];
    result.clLayoutShanYanSloganCenterY = layout[@"setShanYanSloganCenterY"];

    // 窗口坐标必须成对提供，防止只传一轴时把另一轴静默改成零。
    NSNumber *centerX = layout[@"setAuthWindowOrientationCenterX"];
    NSNumber *centerY = layout[@"setAuthWindowOrientationCenterY"];
    if (centerX && centerY) {
        result.clAuthWindowOrientationCenter = [NSValue valueWithCGPoint:CGPointMake(centerX.floatValue, centerY.floatValue)];
    }
    NSNumber *originX = layout[@"setAuthWindowOrientationOriginX"];
    NSNumber *originY = layout[@"setAuthWindowOrientationOriginY"];
    if (originX && originY) {
        result.clAuthWindowOrientationOrigin = [NSValue valueWithCGPoint:CGPointMake(originX.floatValue, originY.floatValue)];
    }
    result.clAuthWindowOrientationWidth = layout[@"setAuthWindowOrientationWidth"];
    result.clAuthWindowOrientationHeight = layout[@"setAuthWindowOrientationHeight"];
    return result;
}

- (void)finishAuthControllerCompletion:(FlutterResult)completion{
    // 先移除当前页 toast，再关闭 SDK 页面；提示没有模态动画或待确认回执。
    self.activeRequestId = nil;
    [self clearAuthError];
    [CLShanYanSDKManager finishAuthControllerAnimated:YES
                                           Completion:^{
        if (completion) {
            [ShanyanPlugin performMainBlock:^{
                completion(nil);
            }];
        }
    }];
}


-(void)startAuthentication:(FlutterResult)authenticationListener{
    [CLShanYanSDKManager mobileCheckWithLocalPhoneNumberComplete:^(CLCompleteResult * _Nonnull completeResult) {
        if (authenticationListener) {
            authenticationListener([ShanyanPlugin completeResultToJson:completeResult]);
        }
    }];
}




// 获取栈顶 UIViewController
//- (UIViewController *)findVisibleVC {
//    UIViewController *visibleVc = nil;
//    UIWindow *visibleWindow = nil;
//    NSArray *windows = [[UIApplication sharedApplication] windows];
//    for (UIWindow *window in windows) {
//        if (!window.hidden && !visibleWindow) {
//            visibleWindow = window;
//        }
//        if ([UIWindow instancesRespondToSelector:@selector(rootViewController)]) {
//            if ([window rootViewController]) {
//                visibleVc = window.rootViewController;
//                break;
//            }
//        }
//    }
//    
//    return visibleVc ?: [[UIApplication sharedApplication].delegate window].rootViewController;
//}


+ (void)performMainBlock:(void(^)(void))block{
    if ([[NSThread currentThread] isMainThread]) {
        block();
    }else{
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (UIViewController *)findVisibleVC {
    UIWindow *keyWindow = nil;

    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }

    UIViewController *rootVC = keyWindow.rootViewController;

    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }

    return rootVC;
}

@end
