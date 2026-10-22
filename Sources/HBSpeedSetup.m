//
//  HBSpeedSetup.m
//

#import "HBSpeedSetup.h"
#import "HBSpeedHook.h"
#import "HBSpeedConfig.h"
#import <UIKit/UIKit.h>

@implementation HBSpeedSetup
@end

static void HBOnSpeedSettingsChanged(CFNotificationCenterRef center,
                                     void *observer,
                                     CFStringRef name,
                                     const void *object,
                                     CFDictionaryRef userInfo)
{
    // 配置热更新：把新速度立刻套到已有窗口（可选，删掉这段就是纯「重启生效」）
    HBApplyUISpeedToAllWindows();
}

void HBSetupUISpeedFeature(void)
{
    static BOOL done = NO;
    if (done) return;
    done = YES;

    HBInstallUISpeedHook();                 // 核心：hook -[UIWindow setWindowLevel:]
    HBApplyUISpeedToAllWindows();           // 已存在的窗口先套一次

    // 配置变化时的热更新（可选）
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    HBOnSpeedSettingsChanged,
                                    CFSTR("HBSpeedSettingsDidChange"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}
