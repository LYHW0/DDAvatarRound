// LYHW integrated native glass tab bar, adapted from DD runtime engine.
// No global UIView/UITabBar hooks, no chrome/container stripping, no geometry takeover.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#if __has_include(<substrate.h>)
#import <substrate.h>
#elif __has_include(<CydiaSubstrate.h>)
#import <CydiaSubstrate.h>
#else
extern void MSHookMessageEx(Class cls, SEL sel, IMP imp, IMP *result);
#endif
#import "LYHWGlassTabBar.h"
#import "LYHWConfig.h"
#define WCLGLog(...) do {} while (0)
#define WCLGInfo(...) NSLog(@"[LYHWGlass] " __VA_ARGS__)
static BOOL sWCLGEnabled;
static NSBundle *sWCLGMainBundle;
static NSString *const kWCLGDesignKey = @"UIDesignRequiresCompatibility";
static NSInteger sWCLGLayoutDepth;
static const CFTimeInterval kWCLGMinPassInterval = 0.05;
static const NSUInteger kWCLGMaxPassesPerSecond = 20;
static BOOL WCLGEnabled(void) { return sWCLGEnabled; }
static BOOL WCLGFinite(CGFloat v) { return isfinite(v); }
static BOOL WCLGFiniteRect(CGRect r) {
    return isfinite(r.origin.x) && isfinite(r.origin.y) && isfinite(r.size.width) && isfinite(r.size.height);
}
static CGFloat WCLGColorAlpha(UIColor *c) { return c ? CGColorGetAlpha(c.CGColor) : 0; }
static BOOL WCLGIsIOS26OrLater(void) {
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){26,0,0}];
}
// The integrated LYHW engine is always a coexisting corner engine. Never move items.
static BOOL WCLGDetectCoexistPlugins(void) { return YES; }
BOOL LYHWGlassTabBarIsActive(void) { return sWCLGEnabled; }
BOOL LYHWGlassTabBarOwnsBottomBar(UIView *view) {
    if (!sWCLGEnabled) return NO;
    return [view isKindOfClass:UITabBar.class] ||
        (NSClassFromString(@"MMTabBar") && [view isKindOfClass:NSClassFromString(@"MMTabBar")]);
}
static NSUserDefaults *sGlassDefaults;
static BOOL sDisableMask, sStereo, sGlow, sLongPress, sSlidingMask, sHideRedDot, sHideBadge, sHideText;
static void LYHWGlassReadFeatures(void) {
    sDisableMask = [sGlassDefaults boolForKey:@"glassDisableMask"];
    sStereo = [sGlassDefaults boolForKey:@"glassStereo"];
    sGlow = [sGlassDefaults boolForKey:@"glassGlow"];
    sLongPress = [sGlassDefaults boolForKey:@"glassLongPress"];
    sSlidingMask = [sGlassDefaults objectForKey:@"glassSlidingMask"] ? [sGlassDefaults boolForKey:@"glassSlidingMask"] : YES;
    sHideRedDot = [sGlassDefaults boolForKey:@"glassHideRedDot"];
    sHideBadge = [sGlassDefaults boolForKey:@"glassHideBadge"];
    sHideText = [sGlassDefaults boolForKey:@"glassHideText"];
}
static NSHashTable<UITabBar *> *sGlassBars;
static void LYHWGlassApplyFeatures(UITabBar *bar);
static void WCLGScheduleEdgeRefresh(void) {} // DD's global ScrollEdgeEffectView mutation is intentionally removed.
static void LYHWGlassRefreshTrackedNavigation(void);
static void WCLGTrackTabBar(UITabBar *bar) {
    if (bar) [sGlassBars addObject:bar];
    LYHWGlassRefreshTrackedNavigation();
}
static __weak UITabBar *sWCLGPendingBar = nil;
static BOOL sWCLGPassQueued = NO;
static BOOL sWCLGPassAgain  = NO;
static CFTimeInterval sWCLGLastPassTime = 0;

static BOOL sWCLGInPass = NO;              // 重入闸
static CFTimeInterval sWCLGBudgetStart = 0; // 预算窗口
static NSUInteger sWCLGBudgetUsed = 0;

static BOOL WCLGRunPass(UITabBar *bar);

static void WCLGSchedulePass(UITabBar *bar) {
	if (!bar || !WCLGEnabled() || sWCLGInPass) return;

	sWCLGPendingBar = bar;
	if (sWCLGPassQueued) {
		sWCLGPassAgain = YES;
		return;
	}
	sWCLGPassQueued = YES;
	sWCLGPassAgain = NO;

	CFTimeInterval now = CACurrentMediaTime();
	CFTimeInterval wait = kWCLGMinPassInterval - (now - sWCLGLastPassTime);
	if (!WCLGFinite(wait) || wait < 0) wait = 0;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)),
				   dispatch_get_main_queue(), ^{
		sWCLGPassQueued = NO;
		UITabBar *b = sWCLGPendingBar;
		sWCLGPendingBar = nil;
		BOOL again = sWCLGPassAgain;
		sWCLGPassAgain = NO;
		sWCLGLastPassTime = CACurrentMediaTime();
		if (!b) return;
		BOOL needMore = WCLGRunPass(b);
		if ((again || needMore) && b) WCLGSchedulePass(b);
	});
}

static BOOL WCLGRunPass(UITabBar *bar) {
	if (!bar || !WCLGEnabled()) return NO;
	if (sWCLGInPass) return NO;

	// 每秒预算：超了就退避到下一窗口，绝不让主线程被我们占满
	CFTimeInterval now = CACurrentMediaTime();
	if (now - sWCLGBudgetStart > 1.0) {
		sWCLGBudgetStart = now;
		sWCLGBudgetUsed = 0;
	}
	if (sWCLGBudgetUsed >= kWCLGMaxPassesPerSecond) {
		WCLGLog(@"pass 预算用尽，退避一帧");
		return NO;
	}
	sWCLGBudgetUsed++;
	sWCLGInPass = YES;

	BOOL needMore = NO;
	@try {
        // LYHW is necessarily present: no geometry writes, no system container writes.
        if (sWCLGLayoutDepth > 0) needMore = YES;
        else LYHWGlassApplyFeatures(bar);
	} @catch (NSException *e) {
		WCLGLog(@"pass exception: %@", e);
	} @finally {
		sWCLGInPass = NO;
	}
	return needMore;
}

typedef void (*WCLGObjIMP)(id, SEL);
typedef void (*WCLGObj1IMP)(id, SEL, id);
typedef void (*WCLGBoolIMP)(id, SEL, BOOL);

static BOOL WCLGClassOwnsSelector(Class cls, SEL sel) {
	if (!cls || !sel) return NO;
	unsigned int n = 0;
	Method *list = class_copyMethodList(cls, &n);
	BOOL owns = NO;
	for (unsigned int i = 0; i < n; i++) {
		if (sel_isEqual(method_getName(list[i]), sel)) { owns = YES; break; }
	}
	if (list) free(list);
	return owns;
}

static BOOL WCLGHookInstanceMethod(Class cls, SEL sel, IMP replacement, IMP *original) {
	if (!cls || !sel || !replacement) return NO;
	// Never overwrite an original IMP with our own replacement on retry.
	if (original && *original) return YES;

	Method inherited = class_getInstanceMethod(cls, sel);
	if (!inherited) {
		WCLGLog(@"skip %@ on %@: 类层级里没有这个 selector",
				NSStringFromSelector(sel), NSStringFromClass(cls));
		return NO;
	}
	const char *types = method_getTypeEncoding(inherited);
	if (!types) return NO;
	IMP inheritedIMP = method_getImplementation(inherited);
	if (inheritedIMP == replacement) return NO;

	if (WCLGClassOwnsSelector(cls, sel)) {
		IMP prev = NULL;
		MSHookMessageEx(cls, sel, replacement, &prev);
		if (original) *original = prev ? prev : inheritedIMP;
		WCLGLog(@"hooked own %@ on %@", NSStringFromSelector(sel), NSStringFromClass(cls));
		return YES;
	}

	if (class_addMethod(cls, sel, replacement, types)) {
		if (original) *original = inheritedIMP;
		WCLGLog(@"added override %@ on %@ (父类未受影响)",
				NSStringFromSelector(sel), NSStringFromClass(cls));
		return YES;
	}

	WCLGLog(@"skip %@ on %@: addMethod failed",
			NSStringFromSelector(sel), NSStringFromClass(cls));
	return NO;
}

// ============================================================
#pragma mark - Hook 目标守卫（找到才缓存，找不到下次重扫）
// ============================================================

static Class WCLGClassNamed(NSString *name, Class *cache) {
	if (cache && *cache) return *cache;
	Class c = NSClassFromString(name);
	if (c && cache) *cache = c;
	return c;
}

static Class sWCLGMMTabBarClass = Nil;
static Class sWCLGMMTabBarControllerClass = Nil;
static Class sWCLGWCNavigationBarClass = Nil;

static BOOL WCLGIsTabBarHookTarget(id obj) {
	if (!obj) return NO;
	Class cls = WCLGClassNamed(@"MMTabBar", &sWCLGMMTabBarClass);
	return cls && [obj isKindOfClass:cls];
}

static BOOL WCLGIsNavBarHookTarget(id obj) {
	if (!obj) return NO;
	Class cls = WCLGClassNamed(@"WCCustomNavigationBar", &sWCLGWCNavigationBarClass);
	return cls && [obj isKindOfClass:cls];
}

// ============================================================
#pragma mark - MMTabBar 的 hook 实现
// ============================================================

static const char kWCLGLayoutActiveKey = 0;
static WCLGObjIMP  sOrigTabLayout = NULL;
static WCLGObjIMP  sOrigTabDidMoveToWindow = NULL;
static WCLGObjIMP  sOrigTabDidMoveToSuperview = NULL;
static WCLGObj1IMP sOrigTabTraitChange = NULL;
static WCLGBoolIMP sOrigTabSetHidden = NULL;

static WCLGObj1IMP sOrigTabSetStandardAppearance = NULL;
static WCLGObj1IMP sOrigTabSetScrollEdgeAppearance = NULL;
static WCLGObj1IMP sOrigTabSetBackgroundImage = NULL;
static WCLGObj1IMP sOrigTabSetShadowImage = NULL;
static WCLGObj1IMP sOrigTabSetBarTintColor = NULL;
static WCLGObj1IMP sOrigTabSetBackgroundColor = NULL;

// ⚠️ 布局里绝不做写操作：只记深度、只排队
static void WCLGTabLayoutSubviews(id self, SEL _cmd) {
	if ([objc_getAssociatedObject(self, &kWCLGLayoutActiveKey) boolValue]) return;
	objc_setAssociatedObject(self, &kWCLGLayoutActiveKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	sWCLGLayoutDepth++;
	@try {
		if (sOrigTabLayout) sOrigTabLayout(self, _cmd);
	} @finally {
		sWCLGLayoutDepth--;
		objc_setAssociatedObject(self, &kWCLGLayoutActiveKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	if (!WCLGIsTabBarHookTarget(self) || !WCLGEnabled()) return;
	WCLGTrackTabBar((UITabBar *)self);
	WCLGSchedulePass((UITabBar *)self);
}

static void WCLGTabDidMoveToWindow(id self, SEL _cmd) {
	if (sOrigTabDidMoveToWindow) sOrigTabDidMoveToWindow(self, _cmd);
	if (!WCLGIsTabBarHookTarget(self) || !WCLGEnabled()) return;
	WCLGTrackTabBar((UITabBar *)self);
	WCLGSchedulePass((UITabBar *)self);
	WCLGScheduleEdgeRefresh();
}

static void WCLGTabDidMoveToSuperview(id self, SEL _cmd) {
	if (sOrigTabDidMoveToSuperview) sOrigTabDidMoveToSuperview(self, _cmd);
	if (!WCLGIsTabBarHookTarget(self) || !WCLGEnabled()) return;
	WCLGSchedulePass((UITabBar *)self);
}

static void WCLGTabTraitCollectionDidChange(id self, SEL _cmd, id previous) {
	if (sOrigTabTraitChange) sOrigTabTraitChange(self, _cmd, previous);
	if (!WCLGIsTabBarHookTarget(self) || !WCLGEnabled()) return;
	WCLGSchedulePass((UITabBar *)self);
}

static void WCLGTabSetHidden(id self, SEL _cmd, BOOL hidden) {
	if (sOrigTabSetHidden) sOrigTabSetHidden(self, _cmd, hidden);
	if (!WCLGIsTabBarHookTarget(self) || !WCLGEnabled()) return;
	WCLGScheduleEdgeRefresh();
	WCLGSchedulePass((UITabBar *)self);
}

// —— 吞掉微信的 appearance 覆盖，保留系统默认（浮动玻璃的来源）——
static void WCLGTabSetStandardAppearance(id self, SEL _cmd, id appearance) {
	if (WCLGIsTabBarHookTarget(self) && WCLGEnabled()) return;
	if (sOrigTabSetStandardAppearance) sOrigTabSetStandardAppearance(self, _cmd, appearance);
}

static void WCLGTabSetScrollEdgeAppearance(id self, SEL _cmd, id appearance) {
	if (WCLGIsTabBarHookTarget(self) && WCLGEnabled()) return;
	if (sOrigTabSetScrollEdgeAppearance) sOrigTabSetScrollEdgeAppearance(self, _cmd, appearance);
}

static void WCLGTabSetBackgroundImage(id self, SEL _cmd, id image) {
	if (WCLGIsTabBarHookTarget(self) && WCLGEnabled()) return;
	if (sOrigTabSetBackgroundImage) sOrigTabSetBackgroundImage(self, _cmd, image);
}

static void WCLGTabSetShadowImage(id self, SEL _cmd, id image) {
	if (WCLGIsTabBarHookTarget(self) && WCLGEnabled()) return;
	if (sOrigTabSetShadowImage) sOrigTabSetShadowImage(self, _cmd, image);
}

static void WCLGTabSetBarTintColor(id self, SEL _cmd, id color) {
	if (WCLGIsTabBarHookTarget(self) && WCLGEnabled()) return;
	if (sOrigTabSetBarTintColor) sOrigTabSetBarTintColor(self, _cmd, color);
}

// 背景色：只挡不透明的（并且只挡微信底栏，别的视图一律放行）
static void WCLGTabSetBackgroundColor(id self, SEL _cmd, UIColor *color) {
	if (WCLGIsTabBarHookTarget(self) && WCLGEnabled()) {
		if (color && WCLGColorAlpha(color) > 0.01) return;
	}
	if (sOrigTabSetBackgroundColor) sOrigTabSetBackgroundColor(self, _cmd, color);
}

static BOOL WCLGInstallTabBarHooks(void) {
	static BOOL installed = NO;
	if (installed) return YES;

	Class cls = WCLGClassNamed(@"MMTabBar", &sWCLGMMTabBarClass);
	if (!cls) return NO;

	WCLGHookInstanceMethod(cls, @selector(layoutSubviews), (IMP)&WCLGTabLayoutSubviews, (IMP *)&sOrigTabLayout);
	WCLGHookInstanceMethod(cls, @selector(didMoveToWindow), (IMP)&WCLGTabDidMoveToWindow, (IMP *)&sOrigTabDidMoveToWindow);
	WCLGHookInstanceMethod(cls, @selector(didMoveToSuperview), (IMP)&WCLGTabDidMoveToSuperview, (IMP *)&sOrigTabDidMoveToSuperview);
	WCLGHookInstanceMethod(cls, @selector(traitCollectionDidChange:), (IMP)&WCLGTabTraitCollectionDidChange, (IMP *)&sOrigTabTraitChange);
	WCLGHookInstanceMethod(cls, @selector(setHidden:), (IMP)&WCLGTabSetHidden, (IMP *)&sOrigTabSetHidden);

	WCLGHookInstanceMethod(cls, NSSelectorFromString(@"setStandardAppearance:"),
						   (IMP)&WCLGTabSetStandardAppearance, (IMP *)&sOrigTabSetStandardAppearance);
	WCLGHookInstanceMethod(cls, NSSelectorFromString(@"setScrollEdgeAppearance:"),
						   (IMP)&WCLGTabSetScrollEdgeAppearance, (IMP *)&sOrigTabSetScrollEdgeAppearance);
	WCLGHookInstanceMethod(cls, NSSelectorFromString(@"setBackgroundImage:"),
						   (IMP)&WCLGTabSetBackgroundImage, (IMP *)&sOrigTabSetBackgroundImage);
	WCLGHookInstanceMethod(cls, NSSelectorFromString(@"setShadowImage:"),
						   (IMP)&WCLGTabSetShadowImage, (IMP *)&sOrigTabSetShadowImage);
	WCLGHookInstanceMethod(cls, NSSelectorFromString(@"setBarTintColor:"),
						   (IMP)&WCLGTabSetBarTintColor, (IMP *)&sOrigTabSetBarTintColor);
	WCLGHookInstanceMethod(cls, @selector(setBackgroundColor:),
						   (IMP)&WCLGTabSetBackgroundColor, (IMP *)&sOrigTabSetBackgroundColor);

	installed = YES;
	WCLGInfo(@"MMTabBar hook 安装完成");
	return YES;
}

// ============================================================
#pragma mark - MMTabBarController.relayoutButtons:
// ============================================================

typedef void (*WCLGRelayoutIMP)(id, SEL, BOOL);
static WCLGRelayoutIMP sOrigRelayout = NULL;

static void WCLGRelayoutButtonsHook(id self, SEL _cmd, BOOL animated) {
	if (sOrigRelayout) sOrigRelayout(self, _cmd, animated);
	if (!WCLGEnabled()) return;
	@try {
		UITabBar *bar = [(UITabBarController *)self tabBar];
		if (!bar) return;
		WCLGSchedulePass(bar);
	} @catch (NSException *e) {
		WCLGLog(@"relayoutButtons exception: %@", e);
	}
}

static void WCLGInstallTabBarControllerHooks(void) {
	static BOOL installed = NO;
	if (installed) return;
	Class cls = WCLGClassNamed(@"MMTabBarController", &sWCLGMMTabBarControllerClass);
	if (!cls) return;
	SEL sel = NSSelectorFromString(@"relayoutButtons:");
	if (!sel || !class_getInstanceMethod(cls, sel)) return;
	installed = WCLGHookInstanceMethod(cls, sel, (IMP)&WCLGRelayoutButtonsHook, (IMP *)&sOrigRelayout);
}

static const void *kWCLGPatchedInfoKey = &kWCLGPatchedInfoKey;

static NSDictionary *WCLGPatchedInfoDictionary(NSDictionary *src) {
	if (!src) return src;

	NSDictionary *patched = objc_getAssociatedObject(src, kWCLGPatchedInfoKey);
	if (patched) return patched;

	@try {
		NSMutableDictionary *m = [src mutableCopy];
		if (!m) return src;
		m[kWCLGDesignKey] = @NO;
		patched = [m copy];
		if (patched) {
			objc_setAssociatedObject(src, kWCLGPatchedInfoKey, patched, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
	} @catch (NSException *e) {
		WCLGLog(@"patch info dictionary exception: %@", e);
	}
	return patched ?: src;
}

typedef id (*WCLGObjKeyIMP)(id, SEL, id);
typedef id (*WCLGObjRetIMP)(id, SEL);

static WCLGObjKeyIMP sOrigBundleObjectForInfoKey = NULL;
static WCLGObjRetIMP sOrigBundleInfoDictionary = NULL;
static WCLGObjRetIMP sOrigBundleLocalizedInfoDictionary = NULL;

static BOOL WCLGIsMainBundleSelf(id self) {
	return (sWCLGMainBundle && self == sWCLGMainBundle);
}

static id WCLGBundleObjectForInfoDictionaryKey(id self, SEL _cmd, NSString *key) {
	if (WCLGEnabled() && WCLGIsMainBundleSelf(self) && [key isEqualToString:kWCLGDesignKey]) {
		return @NO;
	}
	return sOrigBundleObjectForInfoKey ? sOrigBundleObjectForInfoKey(self, _cmd, key) : nil;
}

static id WCLGBundleInfoDictionary(id self, SEL _cmd) {
	id d = sOrigBundleInfoDictionary ? sOrigBundleInfoDictionary(self, _cmd) : nil;
	if (!WCLGEnabled() || !d || ![d isKindOfClass:[NSDictionary class]] || !WCLGIsMainBundleSelf(self)) return d;
	if ([d objectForKey:kWCLGDesignKey] == nil) return d;
	return WCLGPatchedInfoDictionary(d);
}

static id WCLGBundleLocalizedInfoDictionary(id self, SEL _cmd) {
	id d = sOrigBundleLocalizedInfoDictionary ? sOrigBundleLocalizedInfoDictionary(self, _cmd) : nil;
	if (!WCLGEnabled() || !d || ![d isKindOfClass:[NSDictionary class]] || !WCLGIsMainBundleSelf(self)) return d;
	if ([d objectForKey:kWCLGDesignKey] == nil) return d;
	return WCLGPatchedInfoDictionary(d);
}

static void WCLGInstallBundleHooks(void) {
	static BOOL installed = NO;
	if (installed) return;
	Class cls = [NSBundle class];
	WCLGHookInstanceMethod(cls, @selector(objectForInfoDictionaryKey:),
						   (IMP)&WCLGBundleObjectForInfoDictionaryKey, (IMP *)&sOrigBundleObjectForInfoKey);
	WCLGHookInstanceMethod(cls, @selector(infoDictionary),
						   (IMP)&WCLGBundleInfoDictionary, (IMP *)&sOrigBundleInfoDictionary);
	WCLGHookInstanceMethod(cls, @selector(localizedInfoDictionary),
						   (IMP)&WCLGBundleLocalizedInfoDictionary, (IMP *)&sOrigBundleLocalizedInfoDictionary);
	installed = YES;
}


#pragma mark - Scoped feature state (no system lens or platter mutation)
static char kGlassState;
@interface LYHWGlassBarState : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, weak) UITabBar *bar;
@property(nonatomic, strong) CAShapeLayer *selection;
@property(nonatomic, strong) CAShapeLayer *underlay;
@property(nonatomic, strong) UILongPressGestureRecognizer *press;
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *hiddenValues;
@property(nonatomic, assign) CGRect selectedRect;
- (void)longPress:(UILongPressGestureRecognizer *)gesture;
@end

// Traverse only to locate actual item/button roots; no setters on intervening containers.
static void LYHWGlassCollectItems(UIView *view, NSMutableArray<UIView *> *items, NSUInteger depth) {
    if (depth > 12) return;
    for (UIView *sub in view.subviews) {
        NSString *name = NSStringFromClass(sub.class);
        BOOL target = [name containsString:@"MMTabBarItemView"] ||
            [name containsString:@"UITabBarButton"] || [name containsString:@"UITabButton"];
        if (target) [items addObject:sub];
        else LYHWGlassCollectItems(sub, items, depth + 1);
    }
}
static BOOL LYHWGlassBadgeName(NSString *name) {
    NSString *lower = name.lowercaseString;
    return [lower containsString:@"badge"] || [lower containsString:@"reddot"] ||
        [lower containsString:@"red_dot"] || [lower containsString:@"newmessage"] ||
        [lower containsString:@"unread"];
}
static NSString *LYHWGlassBadgeText(UIView *view, NSUInteger depth) {
    if (depth > 5) return nil;
    if ([view isKindOfClass:UILabel.class]) return ((UILabel *)view).text;
    if ([view isKindOfClass:UIButton.class]) return ((UIButton *)view).currentTitle;
    for (UIView *sub in view.subviews) {
        NSString *text = LYHWGlassBadgeText(sub, depth + 1);
        if (text.length) return text;
    }
    return nil;
}
static void LYHWGlassSetFeatureHidden(LYHWGlassBarState *state, UIView *view, BOOL hide) {
    NSNumber *saved = [state.hiddenValues objectForKey:view];
    if (hide) {
        if (!saved) [state.hiddenValues setObject:@(view.hidden) forKey:view];
        if (!view.hidden) view.hidden = YES;
    } else if (saved) {
        if (view.hidden != saved.boolValue) view.hidden = saved.boolValue;
        [state.hiddenValues removeObjectForKey:view];
    }
}
static void LYHWGlassStyleItem(LYHWGlassBarState *state, UIView *view, NSUInteger depth) {
    if (depth > 10) return;
    NSString *name = NSStringFromClass(view.class);
    if (LYHWGlassBadgeName(name)) {
        NSString *text = LYHWGlassBadgeText(view, 0);
        // Numeric badges (including 99+) and text badges are not pure red dots.
        BOOL dot = !text.length;
        LYHWGlassSetFeatureHidden(state, view, dot ? sHideRedDot : sHideBadge);
        return; // Never hide a badge's UILabel as tab title.
    }
    if ([view isKindOfClass:UILabel.class]) LYHWGlassSetFeatureHidden(state, view, sHideText);
    for (UIView *sub in view.subviews) LYHWGlassStyleItem(state, sub, depth + 1);
}
static void LYHWGlassRestore(LYHWGlassBarState *state) {
    for (UIView *view in state.hiddenValues.keyEnumerator.allObjects) {
        LYHWGlassSetFeatureHidden(state, view, NO);
    }
}
static BOOL LYHWGlassItemSelected(UIView *item) {
    if ([item isKindOfClass:UIControl.class]) return ((UIControl *)item).selected;
    SEL selector = NSSelectorFromString(@"isSelected");
    if ([item respondsToSelector:selector]) return ((BOOL (*)(id, SEL))objc_msgSend)(item, selector);
    return NO;
}
static void LYHWGlassApplyFeatures(UITabBar *bar) {
    if (!bar.window || !WCLGEnabled()) return;
    LYHWGlassBarState *state = objc_getAssociatedObject(bar, &kGlassState);
    if (!state) {
        state = [LYHWGlassBarState new];
        state.bar = bar;
        state.hiddenValues = [NSMapTable weakToStrongObjectsMapTable];
        state.selection = [CAShapeLayer layer];
        state.selection.name = @"LYHWGlassSelection";
        state.underlay = [CAShapeLayer layer];
        state.underlay.name = @"LYHWGlassUnderlay";
        // Independent layers only. Never change native glass masks, alpha or subviews.
        [bar.layer addSublayer:state.underlay];
        [bar.layer insertSublayer:state.selection above:state.underlay];
        objc_setAssociatedObject(bar, &kGlassState, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    LYHWGlassCollectItems(bar, items, 0);
    // Items may be replaced or reparented by UIKit. Release our mutations on obsolete views.
    for (UIView *old in state.hiddenValues.keyEnumerator.allObjects) {
        BOOL stillInItem = NO;
        for (UIView *item in items) if ([old isDescendantOfView:item]) { stillInItem = YES; break; }
        if (!stillInItem) LYHWGlassSetFeatureHidden(state, old, NO);
    }
    CGRect selected = CGRectNull;
    for (UIView *item in items) {
        LYHWGlassStyleItem(state, item, 0);
        if (LYHWGlassItemSelected(item)) selected = [item convertRect:item.bounds toView:bar];
    }
    NSMutableArray *systemItems = [NSMutableArray array], *wechatItems = [NSMutableArray array];
    for (UIView *item in items) {
        if ([NSStringFromClass(item.class) containsString:@"MMTabBarItem"]) [wechatItems addObject:item];
        else [systemItems addObject:item];
    }
    for (NSMutableArray<UIView *> *group in @[systemItems, wechatItems]) {
        if (!CGRectIsNull(selected) || !bar.selectedItem || group.count != bar.items.count) continue;
        [group sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
            CGFloat ax = [a convertPoint:CGPointZero toView:bar].x;
            CGFloat bx = [b convertPoint:CGPointZero toView:bar].x;
            return ax < bx ? NSOrderedAscending : ax > bx ? NSOrderedDescending : NSOrderedSame;
        }];
        NSUInteger index = [bar.items indexOfObjectIdenticalTo:bar.selectedItem];
        if (bar.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft && index < group.count) index = group.count - 1 - index;
        if (index < group.count) selected = [group[index] convertRect:group[index].bounds toView:bar];
    }
    BOOL valid = WCLGFiniteRect(selected) && !CGRectIsEmpty(selected) &&
        CGRectContainsRect(CGRectInset(bar.bounds, -1, -1), selected);
    if (valid) selected = CGRectInset(selected, 3, 3);
    CGPathRef path = valid ? [UIBezierPath bezierPathWithRoundedRect:selected cornerRadius:MIN(24, selected.size.height / 2)].CGPath : NULL;
    BOOL moved = !CGRectEqualToRect(selected, state.selectedRect);
    CGPathRef oldPath = state.selection.presentationLayer ? ((CAShapeLayer *)state.selection.presentationLayer).path : state.selection.path;
    CABasicAnimation *slide = nil;
    if (moved && sSlidingMask && !sDisableMask && oldPath && path && !UIAccessibilityIsReduceMotionEnabled()) {
        slide = [CABasicAnimation animationWithKeyPath:@"path"];
        slide.fromValue = (__bridge id)oldPath;
        slide.toValue = (__bridge id)path;
        slide.duration = 0.22;
        slide.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (moved || !state.selection.path) {
        state.selection.path = path;
        state.underlay.path = path;
        state.underlay.shadowPath = path;
        state.selectedRect = selected;
    }
    UIColor *tint = bar.tintColor ?: UIColor.systemGreenColor;
    CGColorRef fill = [tint colorWithAlphaComponent:0.045].CGColor;
    if (!state.selection.fillColor || !CGColorEqualToColor(state.selection.fillColor, fill)) state.selection.fillColor = fill;
    BOOL hideMask = sDisableMask || !valid;
    if (state.selection.hidden != hideMask) state.selection.hidden = hideMask;
    if (!sSlidingMask || sDisableMask) [state.selection removeAnimationForKey:@"LYHW.slide"];
    BOOL hideUnderlay = (!sStereo && !sGlow) || !valid;
    if (state.underlay.hidden != hideUnderlay) state.underlay.hidden = hideUnderlay;
    CGColorRef base = [UIColor.clearColor colorWithAlphaComponent:0].CGColor;
    if (!state.underlay.fillColor || !CGColorEqualToColor(state.underlay.fillColor, base)) state.underlay.fillColor = base;
    CGColorRef stroke = [UIColor.whiteColor colorWithAlphaComponent:sStereo ? 0.45 : 0].CGColor;
    if (!state.underlay.strokeColor || !CGColorEqualToColor(state.underlay.strokeColor, stroke)) state.underlay.strokeColor = stroke;
    CGColorRef shadow = sGlow ? tint.CGColor : UIColor.blackColor.CGColor;
    if (!state.underlay.shadowColor || !CGColorEqualToColor(state.underlay.shadowColor, shadow)) state.underlay.shadowColor = shadow;
    float opacity = sGlow ? 0.7 : sStereo ? 0.22 : 0;
    if (state.underlay.shadowOpacity != opacity) state.underlay.shadowOpacity = opacity;
    CGFloat radius = sGlow ? 9 : 3;
    if (state.underlay.shadowRadius != radius) state.underlay.shadowRadius = radius;
    CGSize offset = CGSizeMake(0, sGlow ? 0 : 2);
    if (!CGSizeEqualToSize(state.underlay.shadowOffset, offset)) state.underlay.shadowOffset = offset;
    [CATransaction commit];
    if (slide) [state.selection addAnimation:slide forKey:@"LYHW.slide"];
    if (sLongPress && !state.press) {
        state.press = [[UILongPressGestureRecognizer alloc] initWithTarget:state action:@selector(longPress:)];
        state.press.minimumPressDuration = 0.65;
        state.press.cancelsTouchesInView = NO;
        state.press.delaysTouchesBegan = NO;
        state.press.delaysTouchesEnded = NO;
        state.press.delegate = state;
        [bar addGestureRecognizer:state.press];
    } else if (!sLongPress && state.press) {
        [bar removeGestureRecognizer:state.press];
        state.press = nil;
    }
}

@implementation LYHWGlassBarState
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b { return YES; }
- (void)longPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || !sLongPress) return;
    UIViewController *presenter = self.bar.window.rootViewController;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    if (!presenter || [presenter isKindOfClass:UIAlertController.class]) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"LYHW 原生玻璃底栏" message:@"快捷开关仅调整 LYHW 自定义效果；系统原生玻璃保持不变。" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *entries = @[
        @[@"关闭选中遮罩", @"glassDisableMask", @(sDisableMask)],
        @[@"立体效果", @"glassStereo", @(sStereo)],
        @[@"发光效果", @"glassGlow", @(sGlow)],
        @[@"遮罩滑动", @"glassSlidingMask", @(sSlidingMask)],
        @[@"隐藏文字", @"glassHideText", @(sHideText)],
        @[@"隐藏数字角标", @"glassHideBadge", @(sHideBadge)],
        @[@"隐藏纯红点", @"glassHideRedDot", @(sHideRedDot)],
        @[@"长按快捷菜单", @"glassLongPress", @(sLongPress)]
    ];
    for (NSArray *entry in entries) {
        NSString *title = [NSString stringWithFormat:@"%@ %@", [entry[2] boolValue] ? @"✓" : @"○", entry[0]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [sGlassDefaults setBool:![entry[2] boolValue] forKey:entry[1]];
            [[NSNotificationCenter defaultCenter] postNotificationName:LYHWSettingsChangedNotification object:nil];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.bar;
    sheet.popoverPresentationController.sourceRect = CGRectMake([gesture locationInView:self.bar].x, 0, 1, 1);
    [presenter presentViewController:sheet animated:YES completion:nil];
}
@end

#pragma mark - Right bar button shared background (not UINavigationItem)
static NSMapTable<UIBarButtonItem *, NSNumber *> *sGlassNavOriginals;
static NSHashTable<UINavigationBar *> *sGlassNavBars;
static BOOL sGlassNavQueued;
static void LYHWGlassSetSharedBackground(UIBarButtonItem *item, BOOL hide) {
    SEL setter = NSSelectorFromString(@"setHidesSharedBackground:");
    SEL getter = NSSelectorFromString(@"hidesSharedBackground");
    if (![item respondsToSelector:setter] || ![item respondsToSelector:getter]) return;
    BOOL current = ((BOOL (*)(id, SEL))objc_msgSend)(item, getter);
    NSNumber *saved = [sGlassNavOriginals objectForKey:item];
    if (hide && !saved) [sGlassNavOriginals setObject:@(current) forKey:item];
    BOOL target = hide ? YES : (saved ? saved.boolValue : current);
    if (current != target) ((void (*)(id, SEL, BOOL))objc_msgSend)(item, setter, target);
    if (!hide) [sGlassNavOriginals removeObjectForKey:item];
}
static void LYHWGlassScheduleNav(UINavigationBar *bar) {
    if (!sWCLGEnabled || !bar) return;
    [sGlassNavBars addObject:bar];
    if (sGlassNavQueued) return;
    sGlassNavQueued = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        sGlassNavQueued = NO;
        if (sWCLGLayoutDepth > 0) { LYHWGlassScheduleNav(bar); return; }
        NSHashTable *targets = [NSHashTable weakObjectsHashTable];
        for (UINavigationBar *nav in sGlassNavBars) {
            // Home tab's root navigation item only. Do not affect pushed chat/search pages.
            if (!nav.window || nav.topItem != nav.items.firstObject) continue;
            BOOL homeWindow = NO;
            for (UITabBar *tab in sGlassBars) {
                if (tab.window == nav.window && !tab.hidden) { homeWindow = YES; break; }
            }
            if (!homeWindow) continue;
            for (UIBarButtonItem *item in nav.topItem.rightBarButtonItems) [targets addObject:item];
        }
        for (UIBarButtonItem *item in sGlassNavOriginals.keyEnumerator.allObjects) {
            if (![targets containsObject:item]) LYHWGlassSetSharedBackground(item, NO);
        }
        for (UIBarButtonItem *item in targets) LYHWGlassSetSharedBackground(item, YES);
    });
}
static void LYHWGlassRefreshTrackedNavigation(void) {
    for (UINavigationBar *bar in sGlassNavBars) LYHWGlassScheduleNav(bar);
}
static WCLGObjIMP sGlassOrigNavLayout;
static void LYHWGlassNavLayout(id self, SEL cmd) {
    if ([objc_getAssociatedObject(self, &kWCLGLayoutActiveKey) boolValue]) return;
    objc_setAssociatedObject(self, &kWCLGLayoutActiveKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sWCLGLayoutDepth++;
    @try { if (sGlassOrigNavLayout) sGlassOrigNavLayout(self, cmd); }
    @finally {
        sWCLGLayoutDepth--;
        objc_setAssociatedObject(self, &kWCLGLayoutActiveKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    LYHWGlassScheduleNav((UINavigationBar *)self);
}
static BOOL LYHWGlassInstallNavigation(void) {
    // Select exactly ONE concrete family; do not reuse an original IMP across classes.
    static Class installedClass;
    if (installedClass) return YES;
    Class cls = NSClassFromString(@"MMUINavigationBar");
    if (!cls) cls = NSClassFromString(@"WCCustomNavigationBar");
    BOOL ok = cls && WCLGHookInstanceMethod(cls, @selector(layoutSubviews), (IMP)LYHWGlassNavLayout, (IMP *)&sGlassOrigNavLayout);
    if (ok) installedClass = cls;
    return ok;
}
void LYHWGlassTabBarRefresh(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        LYHWGlassReadFeatures();
        if (!sWCLGEnabled) return; // Master is intentionally startup-only.
        for (UITabBar *bar in sGlassBars) WCLGSchedulePass(bar);
        for (UINavigationBar *bar in sGlassNavBars) LYHWGlassScheduleNav(bar);
    });
}
static void LYHWGlassInstallWithRetry(int attempt) {
    if (!sWCLGEnabled) return;
    BOOL tabOK = WCLGInstallTabBarHooks();
    BOOL navOK = LYHWGlassInstallNavigation();
    WCLGInstallTabBarControllerHooks();
    if ((!tabOK || !navOK || !sOrigRelayout) && attempt < 10) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ LYHWGlassInstallWithRetry(attempt + 1); });
    }
}
__attribute__((constructor)) static void LYHWGlassInitialize(void) {
    @autoreleasepool {
        // Same real suite as LYHWConfig.m, not a separate "LYHWConfig" domain.
        sGlassDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.lyhw.LYHW"];
        sWCLGEnabled = WCLGIsIOS26OrLater() && [sGlassDefaults boolForKey:@"glassTabBarEnabled"];
        LYHWGlassReadFeatures();
        [[NSNotificationCenter defaultCenter] addObserverForName:LYHWSettingsChangedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { LYHWGlassTabBarRefresh(); }];
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { LYHWGlassTabBarRefresh(); }];
        if (!sWCLGEnabled) return; // Absolutely no hooks installed when disabled at launch.
        sGlassBars = [NSHashTable weakObjectsHashTable];
        sGlassNavBars = [NSHashTable weakObjectsHashTable];
        sGlassNavOriginals = [NSMapTable weakToStrongObjectsMapTable];
        sWCLGMainBundle = NSBundle.mainBundle;
        // Critical: do not defer the bundle compatibility hooks to the main queue.
        WCLGInstallBundleHooks();
        // MMTabBar classes may already exist: intercept appearance before first construction.
        LYHWGlassInstallWithRetry(0);
    }
}
