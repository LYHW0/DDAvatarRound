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

/// 通话类窗口判定（来电横幅 / 语音 / 视频 / 多屏 / 小窗）
static BOOL LYHWIsCallWindow(UIWindow *w)
{
    if (!w) return NO;
    static NSString *const keys[] = {
        @"VoIP", @"Voip", @"voip", @"MultiTalk", @"Multitalk", @"Voipmp",
        @"Minimize", @"Conference", @"Call", @"Ring"
    };
    NSString *rootName = NSStringFromClass([w.rootViewController class]);
    if (rootName.length == 0) return NO;
    for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
        if ([rootName rangeOfString:keys[i]].location != NSNotFound) return YES;
    }
    return NO;
}

/// 只允许微信主界面窗口变速
///   通话窗口的底色是 VoIPHeadImageBlurView 的虚化层（backdrop），
///   根图层被变速后合成时序被打乱、虚化结果退化成底色 → 表现为「打电话背景全黑」。
///   键盘 / 弹窗 / 来电横幅这些抬高过层级的窗口同理，一律不碰。
static BOOL LYHWWindowEligible(UIWindow *w)
{
    if (!w) return NO;
    if (LYHWIsCallWindow(w)) return NO;
    if (w.windowLevel != UIWindowLevelNormal) return NO;
    UIViewController *root = w.rootViewController;
    if (!root) return NO;
    if ([root isKindOfClass:[UITabBarController class]]) return YES;
    NSString *n = NSStringFromClass([root class]);
    if ([n containsString:@"TabBar"] || [n containsString:@"MainFrame"]) return YES;
    @try {
        id delegate = [UIApplication sharedApplication].delegate;
        if (delegate && [delegate respondsToSelector:@selector(window)] &&
            ((UIWindow *)[delegate performSelector:@selector(window)]) == w) return YES;
    } @catch (__unused NSException *e) {}
    return NO;
}

/// 把速度套到单个窗口；不合格的窗口强制回 1.0（防止旧版本残留 / 热更新后跑偏）
static void LYHWApplySpeedToWindow(UIWindow *w, float speed)
{
    if (!w) return;
    CALayer *l = [w layer];
    if (![l respondsToSelector:@selector(setSpeed:)]) return;
    BOOL want = (speed != LYHWSpeedDefaultValue) && LYHWWindowEligible(w);
    float v = want ? speed : 1.0f;
    if (l.speed != v) [l setSpeed:v];
}

static void hb_setWindowLevel(id self, SEL _cmd, double level)
{
    // 1) 先调原实现，保持微信原始窗口层级逻辑不变
    if (hb_orig_setWindowLevel) {
        hb_orig_setWindowLevel(self, _cmd, level);
    }

    // 2) 取配置（对应 [LYHWConfigUtil editUiWindowsSpeed]）
    float speed = LYHWGetUISpeed();

    // 3) 只给主界面窗口变速；通话 / 来电 / 弹窗窗口一律 1.0
    LYHWApplySpeedToWindow((UIWindow *)self, speed);
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
        LYHWApplySpeedToWindow(w, speed);
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
