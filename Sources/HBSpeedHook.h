//
//  HBSpeedHook.h
//  自定义界面速度 —— 生效层（Hook）
//
//  逆向来源：HBWechatHelper.dylib
//  原实现：
//    安装点 0x38D31C：
//      MSHookMessageEx(objc_getClass("UIWindow"),
//                      @selector(setWindowLevel:),
//                      (IMP)0x4BC32C,
//                      &orig(0x193C248));
//    替换实现 0x4BC32C：
//      call orig(self, _cmd, level);
//      float s = [HBConfigUtil editUiWindowsSpeed];
//      if (s != 1.0f) { [[self layer] setSpeed:s]; }
//
//  为什么挂 setWindowLevel: ？
//    微信在启动 / 建窗时会对每个 UIWindow 调一次 setWindowLevel:，
//    在这里把 window.layer.speed 设成配置值，整棵图层树的时间被统一缩放，
//    所有动画（推页、弹窗、气泡、下拉刷新…）一起变快/变慢。
//    这就是「界面速度」的全部生效原理 —— 只此一个 Hook 点。
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 安装 Hook。重复调用安全（幂等）。
void HBInstallUISpeedHook(void);

/// 卸载 Hook，恢复原实现。
void HBUninstallUISpeedHook(void);

/// 重启宿主 App（原插件用 HBReloadOpenApp，没有则退到 exit(0)）
void HBReloadHostApplication(void);

/// 把当前速度立刻套到所有已存在的窗口上。
/// 原插件靠「重启微信生效」实现，这个方法是等效的免重启通道（可选调用）。
void HBApplyUISpeedToAllWindows(void);

#ifdef __cplusplus
}
#endif
