#import <UIKit/UIKit.h>

// Installed only when glassTabBarEnabled was YES at process launch on iOS 26+.
// Changing the master switch requires restarting WeChat; feature switches are live.
// Native platter is never synthesized or repositioned. Background suppression is
// fail-closed to the dump-confirmed direct UIView/effect(tag 102289) fingerprint;
// mismatched hierarchies stay untouched. Saved background alpha is restored when
// detached/hidden or no longer matching. No UIView-wide hook or item geometry writes.
// Fresh installs show only native selection. Explicit glassDisableMask=NO or
// enabling stereo/glow/sliding opts into bounded custom decoration; DisableMask
// suppresses its fill/slide, not the native liquid lens or separate stereo/glow.
FOUNDATION_EXPORT BOOL LYHWGlassTabBarIsActive(void);
// Corner engine must bypass only bottom-bar rounding, not navigation/cell/avatar handling.
FOUNDATION_EXPORT BOOL LYHWGlassTabBarOwnsBottomBar(UIView *view);
// Main queue refresh; observes LYHWSettingsChangedNotification automatically.
FOUNDATION_EXPORT void LYHWGlassTabBarRefresh(void);
