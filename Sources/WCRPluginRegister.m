//
//  WCRPluginRegister.m
//  LYHW
//
//  把微信内设置页注册进 wcplugins 的"插件收纳"。
//  wcplugins 提供：
//    +[WCPluginsMgr sharedInstance]
//    -[WCPluginsMgr registerControllerWithTitle:version:controller:]
//  其中 controller 参数是类名字符串，插件收纳页会在点击时
//  用 NSClassFromString 实例化并 push。
//  这里全部走运行时，避免对 wcplugins.dylib 产生链接依赖。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static const NSInteger WCRRegisterMaxAttempts = 60;
static const NSTimeInterval WCRRegisterRetryDelay = 0.5;
static BOOL WCRDidRegisterPluginEntry = NO;

static void WCRTryRegisterPluginEntry(NSInteger attempt) {
    if (WCRDidRegisterPluginEntry) return;

    Class mgrClass = NSClassFromString(@"WCPluginsMgr");
    if (mgrClass) {
        id mgr = nil;
        @try {
            mgr = [mgrClass performSelector:@selector(sharedInstance)];
        } @catch (NSException *e) {
            mgr = nil;
        }

        if (mgr && [mgr respondsToSelector:@selector(registerControllerWithTitle:version:controller:)]) {
            @try {
                NSMethodSignature *sig = [mgr methodSignatureForSelector:@selector(registerControllerWithTitle:version:controller:)];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:mgr];
                [inv setSelector:@selector(registerControllerWithTitle:version:controller:)];

                NSString *title = @"兰因后悟";
                NSString *version = @"1.0.0";
                NSString *controllerName = @"WCRPluginSettingsViewController";
                [inv setArgument:&title atIndex:2];
                [inv setArgument:&version atIndex:3];
                [inv setArgument:&controllerName atIndex:4];
                [inv invoke];

                WCRDidRegisterPluginEntry = YES;
                NSLog(@"[LYHW] registered into WCPluginsMgr");
            } @catch (NSException *e) {
                NSLog(@"[LYHW] register failed: %@", e);
            }
        }
    }

    if (WCRDidRegisterPluginEntry) return;
    if (attempt >= WCRRegisterMaxAttempts) {
        NSLog(@"[LYHW] WCPluginsMgr not available, plugin entry not registered");
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(WCRRegisterRetryDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCRTryRegisterPluginEntry(attempt + 1);
    });
}

__attribute__((constructor))
static void WCRPluginRegisterEntry(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        WCRTryRegisterPluginEntry(0);
    });
}
