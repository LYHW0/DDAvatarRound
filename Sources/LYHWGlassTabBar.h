#import <UIKit/UIKit.h>

// Installed only when glassTabBarEnabled was YES at process launch on iOS 26+.
// Changing the master switch requires restarting WeChat; feature switches are live.
FOUNDATION_EXPORT BOOL LYHWGlassTabBarIsActive(void);
// Corner engine must bypass only bottom-bar rounding, not navigation/cell/avatar handling.
FOUNDATION_EXPORT BOOL LYHWGlassTabBarOwnsBottomBar(UIView *view);
// Main queue refresh; observes LYHWSettingsChangedNotification automatically.
FOUNDATION_EXPORT void LYHWGlassTabBarRefresh(void);
