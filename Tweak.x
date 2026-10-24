//
//  Tweak.x  —  LYHW 入口
//
//  只做四件事：
//    1. 启动时把配置读进内存
//    2. iOS 26 的「液态设计」开关必须在 UIKit 起界面之前抹掉，所以单独提前装
//    3. 等主界面窗口就绪之后再装底栏 hook（早装会在启动布局期改视图树 → 闪退）
//    4. 监听跨进程的设置变更（设置面板改完 → 微信里立刻生效）
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LYHWConfig.h"
#import "LYHWSpeedSetup.h"
#import "DYLAppearance.h"
#include "WXFT.h"

// 两个模块的安装入口（定义见 LYHWWCLiquidTabBar.x / WXFloatingTabBar.m）
void ZKInstallLiquidCompatBypass(void);
void ZKInstallLiquidTabBar(void);

static BOOL sLYHWTabBarInstalled = NO;

// 0.5s 一次，最多 16 次（8 秒），等不到窗口就放弃，绝不死循环重试
static const NSInteger kLYHWMaxInstallAttempts = 16;
static const NSTimeInterval kLYHWInstallPoll = 0.5;

#pragma mark - 设置变更

static void LYHWSettingsChangedCallback(CFNotificationCenterRef center,
                                       void *observer,
                                       CFStringRef name,
                                       const void *object,
                                       CFDictionaryRef userInfo) {
    // 设置面板写在另一个进程，收到通知后重新读盘（会一并清掉内存缓存）
    [[LYHWConfig shared] reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification
                                                        object:nil];
}

#pragma mark - 安装时机

// 主界面窗口真正就绪了没有。没就绪就装 hook，等于在启动布局中途改视图树。
static BOOL LYHWMainWindowReady(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) return NO;
    if (app.applicationState == UIApplicationStateBackground) return NO;

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState == UISceneActivationStateUnattached) continue;
        for (UIWindow *w in ws.windows) {
            if (w.isHidden) continue;
            if (w.rootViewController == nil) continue;
            if (w.windowLevel > UIWindowLevelNormal + 2) continue; // 跳过键盘/浮层窗口
            if (w.bounds.size.width < 1.0 || w.bounds.size.height < 1.0) continue;
            return YES;
        }
    }
    return NO;
}

static void LYHWInstallTabBarIfNeeded(void) {
    if (sLYHWTabBarInstalled) return;

    LYHWConfig *cfg = [LYHWConfig shared];

    // 安全模式：出问题可以在设置文件里写 LYHWSafeMode=YES，整套底栏模块不加载
    if ([[cfg objectForKey:@"LYHWSafeMode" def:@NO] boolValue]) {
        NSLog(@"[LYHW] safe mode on, tabbar module skipped");
        return;
    }

    BOOL floating = cfg.floatingTabBarEnabled;
    BOOL liquid = cfg.liquidTabBarEnabled;
    if (!floating && !liquid) return;   // 两个都没开，什么都不用装

    sLYHWTabBarInstalled = YES;

    // 两套实现都会改写 MMTabBar，只允许装一套；这里不再回写配置，避免启动期改盘
    if (floating && liquid) {
        NSLog(@"[LYHW] both tabbar modules enabled, falling back to floating");
    }

    @try {
        if (floating) {
            WXFTInstall();
        } else {
            ZKInstallLiquidTabBar();
        }
        NSLog(@"[LYHW] tabbar module installed: %@", floating ? @"floating" : @"liquid");
    } @catch (NSException *e) {
        NSLog(@"[LYHW] tabbar install failed: %@", e);
    }
}

static void LYHWScheduleTabBarInstall(NSInteger attempt) {
    if (sLYHWTabBarInstalled) return;

    LYHWConfig *cfg = [LYHWConfig shared];
    if (!cfg.floatingTabBarEnabled && !cfg.liquidTabBarEnabled) return;

    if (LYHWMainWindowReady() || attempt >= kLYHWMaxInstallAttempts) {
        LYHWInstallTabBarIfNeeded();
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kLYHWInstallPoll * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        LYHWScheduleTabBarInstall(attempt + 1);
    });
}

#pragma mark - 入口

%ctor {
    @autoreleasepool {
        // 先把配置初始化好，避免首个界面加载时读不到
        [LYHWConfig shared];

        // iOS 26 液态设计开关：必须在 UIKit 决定设计模式之前处理，不能等 1.5 秒
        @try {
            ZKInstallLiquidCompatBypass();
        } @catch (NSException *e) {
            NSLog(@"[LYHW] compat bypass failed: %@", e);
        }

        LYHWSetupUISpeedFeature();
        DYLAppearanceStart();

        // 底栏 hook 等到主界面窗口就绪再装
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kLYHWInstallPoll * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            LYHWScheduleTabBarInstall(0);
        });

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        LYHWSettingsChangedCallback,
                                        (__bridge CFStringRef)LYHWSettingsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        NSLog(@"[LYHW] loaded, modules: corner / profileCard / msgBanner / menu / avatarCorner");
    }
}
