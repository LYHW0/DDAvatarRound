//
//  Tweak.x  —  LYHW 入口
//
//  只做三件事：
//    1. 启动时把配置读进内存
//    2. 监听跨进程的设置变更（设置面板改完 → 微信里立刻生效）
//    3. 打印一行版本信息，方便排错
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LYHWConfig.h"
#import "LYHWSpeedSetup.h"
#import "DYLAppearance.h"

void ZKInstallLiquidTabBar(void);

static void LYHWSettingsChangedCallback(CFNotificationCenterRef center,
                                       void *observer,
                                       CFStringRef name,
                                       const void *object,
                                       CFDictionaryRef userInfo) {
    // 设置面板写在另一个进程，收到通知后重新读盘
    [[LYHWConfig shared] reload];
    [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification
                                                        object:nil];
}

%ctor {
    @autoreleasepool {
        // 先把配置初始化好，避免首个界面加载时读不到
        [LYHWConfig shared];
        LYHWSetupUISpeedFeature();
        DYLAppearanceStart();
        if ([LYHWConfig shared].liquidTabBarEnabled) ZKInstallLiquidTabBar();

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        LYHWSettingsChangedCallback,
                                        (__bridge CFStringRef)LYHWSettingsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        NSLog(@"[LYHW] loaded, modules: corner / profileCard / msgBanner / menu / avatarCorner");
    }
}
