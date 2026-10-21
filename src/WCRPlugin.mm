//
//  WCRPlugin.mm
//  插件注册入口 —— 只走 WCPluginsMgr(插件收纳的统一注册中心)
//
//  逆向依据(WCRefine 2.1-9):
//    * 类名字符串 "WCPluginsMgr" 在二进制里是运行时按名字取的(没有编译期类引用),
//      说明上游插件也是运行时注册进去的,而不是编译期链接。
//    * 插件模型类是 WCPluginModel(同样是运行时名字)。
//    * 注册变更后发 WCPluginsMgrDidChangeNotification,让收纳列表刷新。
//    * WCRefine 自己的收纳层是 WCRefinePluginHubManager,
//      对外接口 -registerPluginForCustomEntry:(条目格式 "名称@控制器类名")。
//
//  所以这里按「主入口 WCPluginsMgr → 收纳层 WCRefinePluginHubManager → 设置页兜底」
//  三级顺序注册,任何一级不存在都不会崩。
//

#import "WCRCorner.h"
#import <objc/runtime.h>

NSString *const WCRPluginDidRegisterNotification = @"WCRPluginDidRegisterNotification";
NSString *const WCRPluginEntryTitle = @"界面圆角";
NSString *const WCRPluginEntryControllerName = @"WCRCornerViewController";

#pragma mark - 运行时小工具

static BOOL WCRClassHasInstanceMethod(Class cls, NSString *name) {
    if (!cls) return NO;
    return class_getInstanceMethod(cls, NSSelectorFromString(name)) != NULL;
}

static BOOL WCRClassHasClassMethod(Class cls, NSString *name) {
    if (!cls) return NO;
    return class_getClassMethod(cls, NSSelectorFromString(name)) != NULL;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

/// 依次尝试常见的单例入口
static id WCRSharedInstance(Class cls) {
    if (!cls) return nil;
    NSArray<NSString *> *candidates = @[
        @"sharedInstance", @"sharedManager", @"shared", @"defaultManager",
        @"manager", @"sharedPluginsMgr", @"pluginsMgr", @"instance"
    ];
    for (NSString *sel in candidates) {
        if (WCRClassHasClassMethod(cls, sel)) {
            id v = [cls performSelector:NSSelectorFromString(sel)];
            if (v) return v;
        }
    }
    return nil;
}

#pragma clang diagnostic pop

#pragma mark - 注册器

@interface WCRPluginRegistrar ()
+ (id)makePluginModel;
+ (BOOL)registerIntoPluginsMgr;
+ (BOOL)registerIntoPluginHub;
+ (void)notifyPluginsMgrChanged;
@end

@implementation WCRPluginRegistrar

+ (BOOL)isRegistered {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    return [d boolForKey:@"WCRPluginRegisteredV1"];
}

+ (UIViewController *)makeEntryViewController {
    return [WCRCornerViewController new];
}

#pragma mark 插件模型

/// 构造 WCPluginModel 实例,只填它真的有的字段(全部 respondsToSelector 探测)
+ (id)makePluginModel {
    Class modelCls = NSClassFromString(@"WCPluginModel");
    if (!modelCls) return nil;
    id model = nil;
    @try {
        model = [[modelCls alloc] init];
    } @catch (__unused NSException *e) {
        return nil;
    }
    if (!model) return nil;

    NSDictionary<NSString *, id> *kv = @{
        @"title"              : WCRPluginEntryTitle,
        @"name"               : WCRPluginEntryTitle,
        @"pluginName"         : WCRPluginEntryTitle,
        @"pluginTitle"        : WCRPluginEntryTitle,
        @"identifier"         : @"wcr.corner",
        @"pluginIdentifier"   : @"wcr.corner",
        @"controller"         : WCRPluginEntryControllerName,
        @"controllerClass"    : WCRPluginEntryControllerName,
        @"viewControllerName" : WCRPluginEntryControllerName,
        @"className"          : WCRPluginEntryControllerName,
        @"iconName"           : @"rectangle.roundedtop",
        @"version"            : @"1.0.0",
        @"enabled"            : @YES,
    };
    for (NSString *key in kv) {
        SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",
                                           [[key substringToIndex:1] uppercaseString],
                                           [key substringFromIndex:1]]);
        if ([model respondsToSelector:setter]) {
            @try {
                [model setValue:kv[key] forKey:key];
            } @catch (__unused NSException *e) {
                // 字段存在但类型不同,跳过
            }
        }
    }
    return model;
}

#pragma mark 一级:WCPluginsMgr

/// 返回 YES 表示已经进到 WCPluginsMgr 的注册表里
+ (BOOL)registerIntoPluginsMgr {
    Class mgrCls = NSClassFromString(@"WCPluginsMgr");
    if (!mgrCls) return NO;

    id model = [self makePluginModel];
    id target = WCRSharedInstance(mgrCls);

    // 单例形式的注册
    if (target) {
        NSArray<NSString *> *sels = @[
            @"registerPlugin:", @"registerPluginModel:", @"registerPluginWithModel:",
            @"addPlugin:", @"addPluginModel:", @"register:", @"add:"
        ];
        for (NSString *name in sels) {
            if (WCRClassHasInstanceMethod([target class], name) && model) {
                @try {
                    [target performSelector:NSSelectorFromString(name) withObject:model];
                    return YES;
                } @catch (__unused NSException *e) {
                    continue;
                }
            }
        }
        // 三个参数的常见形态:registerPlugin:title:controller:
        NSArray<NSString *> *multi = @[
            @"registerPlugin:title:controller:", @"addPluginWithTitle:controller:icon:"
        ];
        for (NSString *name in multi) {
            if (WCRClassHasInstanceMethod([target class], name)) {
                @try {
                    SEL s = NSSelectorFromString(name);
                    NSMethodSignature *sig = [target methodSignatureForSelector:s];
                    if (sig.numberOfArguments == 5) {
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        inv.target = target;
                        inv.selector = s;
                        id a1 = WCRPluginEntryTitle;
                        id a2 = WCRPluginEntryControllerName;
                        [inv setArgument:&a1 atIndex:2];
                        [inv setArgument:&a2 atIndex:3];
                        [inv invoke];
                        return YES;
                    }
                } @catch (__unused NSException *e) {
                    continue;
                }
            }
        }
    }

    // 类方法形式的注册
    NSArray<NSString *> *classSels = @[@"registerPlugin:", @"addPlugin:", @"registerPluginModel:"];
    for (NSString *name in classSels) {
        if (WCRClassHasClassMethod(mgrCls, name) && model) {
            @try {
                [mgrCls performSelector:NSSelectorFromString(name) withObject:model];
                return YES;
            } @catch (__unused NSException *e) {
                continue;
            }
        }
    }
    return NO;
}

#pragma mark 二级:WCRefine 插件收纳(WCRefinePluginHubManager)

+ (BOOL)registerIntoPluginHub {
    Class hubCls = NSClassFromString(@"WCRefinePluginHubManager");
    if (!hubCls) return NO;
    id hub = WCRSharedInstance(hubCls);
    NSString *entry = [NSString stringWithFormat:@"%@@%@", WCRPluginEntryTitle, WCRPluginEntryControllerName];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if (hub && WCRClassHasInstanceMethod([hub class], @"registerPluginForCustomEntry:")) {
        @try {
            [hub performSelector:NSSelectorFromString(@"registerPluginForCustomEntry:") withObject:entry];
            return YES;
        } @catch (__unused NSException *e) {}
    }
#pragma clang diagnostic pop
    return NO;
}

#pragma mark 三级:变更通知

+ (void)notifyPluginsMgrChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WCPluginsMgrDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:WCRPluginDidRegisterNotification object:nil];
}

#pragma mark 总入口

+ (void)registerAll {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        BOOL ok = [self registerIntoPluginsMgr];
        BOOL hub = [self registerIntoPluginHub];
        if (ok || hub) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WCRPluginRegisteredV1"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self notifyPluginsMgrChanged];
        }
    });
}

/// 供设置页兜底入口使用:注册没成功时也要能打开面板
+ (BOOL)needsFallbackEntry {
    return ![self isRegistered];
}

@end
