//
//  LYHWSpeedSetup.m
//

#import "LYHWSpeedSetup.h"
#import "LYHWSpeedHook.h"
#import "LYHWSpeedConfig.h"
#import <UIKit/UIKit.h>

@implementation LYHWSpeedSetup
@end

static void LYHWOnSpeedSettingsChanged(CFNotificationCenterRef center,
                                     void *observer,
                                     CFStringRef name,
                                     const void *object,
                                     CFDictionaryRef userInfo)
{
    // 配置热更新：把新速度立刻套到已有窗口（可选，删掉这段就是纯「重启生效」）
    LYHWApplyUISpeedToAllWindows();
}

void LYHWSetupUISpeedFeature(void)
{
    static BOOL done = NO;
    if (done) return;
    done = YES;

    LYHWInstallUISpeedHook();                 // 核心：hook -[UIWindow setWindowLevel:]
    LYHWApplyUISpeedToAllWindows();           // 已存在的窗口先套一次

    // 配置变化时的热更新（可选）
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    LYHWOnSpeedSettingsChanged,
                                    CFSTR("LYHWSpeedSettingsDidChange"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
