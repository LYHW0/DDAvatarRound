#import <UIKit/UIKit.h>

// Installed only when glassTabBarEnabled was YES at process launch on iOS 26+.
// Changing the master switch requires restarting WeChat; feature switches are live.
// Native platter is never synthesized or repositioned. Background suppression is
// fail-closed to the dump-confirmed direct UIView/effect(tag 102289) fingerprint;
// mismatched hierarchies stay untouched. Saved background alpha is restored when
// detached/hidden or no longer matching. No UIView-wide hook or view removal.
// A per-bar coalesced async pass aligns exactly four direct MMTabBarItemViews
// to the live platter grid, centering actual visible icon/title content. Unknown
// hierarchies/nonfinite/transformed geometry fail closed; no native lens writes.
// Fresh installs show only native selection. Explicit mask/sliding settings can
// decorate providers without a live lens; a live lens always owns fill/slide.
// Independent stereo/glow still respect their original switches. DisableMask
// never disables the native liquid lens. No forced opaque white selection.
FOUNDATION_EXPORT BOOL LYHWGlassTabBarIsActive(void);
// Corner engine must bypass only bottom-bar rounding, not navigation/cell/avatar handling.
FOUNDATION_EXPORT BOOL LYHWGlassTabBarOwnsBottomBar(UIView *view);
// Main queue refresh; observes LYHWSettingsChangedNotification automatically.
FOUNDATION_EXPORT void LYHWGlassTabBarRefresh(void);
