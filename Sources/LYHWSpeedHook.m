//
//  LYHWSpeedHook.m
//

#import "LYHWSpeedHook.h"
#include <stdlib.h>
#import "LYHWSpeedConfig.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

typedef void (*LYHWSetWindowLevelFn)(id, SEL, double);
typedef void (*LYHWRestartFn)(id, SEL);

static LYHWSetWindowLevelFn hb_orig_setWindowLevel = NULL;
static IMP                 hb_prev_imp            = NULL;   // method_setImplementation 返回的旧实现
static BOOL                hb_hook_installed      = NO;

#pragma mark - 替换实现（对应原 0x4BC32C）

static void hb_setWindowLevel(id self, SEL _cmd, double level)
{
    // 1) 先调原实现，保持微信原始窗口层级逻辑不变
    if (hb_orig_setWindowLevel) {
        hb_orig_setWindowLevel(self, _cmd, level);
    }

    // 2) 取配置（对应 [LYHWConfigUtil editUiWindowsSpeed]）
    float speed = LYHWGetUISpeed();

    // 3) 与 1.0 不等才动，等于默认值时什么都不做
    if (speed == LYHWSpeedDefaultValue) return;

    // 4) 缩放该窗口根图层的时间轴
    CALayer *layer = [(id)self layer];
    if ([layer respondsToSelector:@selector(setSpeed:)]) {
        [layer setSpeed:speed];
    }
}

#pragma mark - 安装 / 卸载

void LYHWInstallUISpeedHook(void)
{
    if (hb_hook_installed) return;

    Class cls = objc_getClass("UIWindow");
    if (!cls) return;

    Method m = class_getInstanceMethod(cls, @selector(setWindowLevel:));
    if (!m) return;

    hb_orig_setWindowLevel = (LYHWSetWindowLevelFn)method_getImplementation(m);
    hb_prev_imp            = method_setImplementation(m, (IMP)hb_setWindowLevel);
    hb_hook_installed      = YES;
}

void LYHWUninstallUISpeedHook(void)
{
    if (!hb_hook_installed) return;

    Class cls = objc_getClass("UIWindow");
    Method m = class_getInstanceMethod(cls, @selector(setWindowLevel:));
    if (m && hb_prev_imp) {
        method_setImplementation(m, hb_prev_imp);
        hb_prev_imp = NULL;
    }
    hb_hook_installed = NO;
}

#pragma mark - 立即生效（可选）

void LYHWApplyUISpeedToAllWindows(void)
{
    float speed = LYHWGetUISpeed();

    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        if (![w respondsToSelector:@selector(layer)]) continue;
        CALayer *l = [w layer];
        if (![l respondsToSelector:@selector(setSpeed:)]) continue;
        [l setSpeed:(speed == LYHWSpeedDefaultValue ? 1.0f : speed)];
    }
}

#pragma mark - 重启微信（对应原插件 LYHWReloadOpenApp）

void LYHWReloadHostApplication(void)
{
    SEL sel = NSSelectorFromString(@"LYHWReloadOpenApp");
    id app = [UIApplication sharedApplication];
    if ([app respondsToSelector:sel]) {
        ((LYHWRestartFn)objc_msgSend)(app, sel);
        return;
    }
    // 宿主没有重启通道：退到 exit(0)，由用户手动重开
    exit(0);
}
