// LYHW integrated native glass tab bar, adapted from DD runtime engine.
// No global UIView/UITabBar hooks or container stripping. Only real WeChat
// item centers are aligned asynchronously to the native platter's four slots.
// Only the dump-confirmed MMTabBar > UIView > UIVisualEffectView(tag 102289)
// background is reversibly neutralized; native platter/lens/portal trees stay intact.
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
BOOL LYHWGlassTabBarIsActive(void) { return sWCLGEnabled; }
BOOL LYHWGlassTabBarOwnsBottomBar(UIView *view) {
    if (!sWCLGEnabled) return NO;
    return [view isKindOfClass:UITabBar.class] ||
        (NSClassFromString(@"MMTabBar") && [view isKindOfClass:NSClassFromString(@"MMTabBar")]);
}
static NSUserDefaults *sGlassDefaults;
static BOOL sHideRedDot, sHideBadge;
static void LYHWGlassReadFeatures(void) {
    sHideRedDot = [sGlassDefaults boolForKey:@"glassHideRedDot"];
    sHideBadge = [sGlassDefaults boolForKey:@"glassHideBadge"];
}
static NSHashTable<UITabBar *> *sGlassBars;
static void LYHWGlassApplyFeatures(UITabBar *bar);
static void WCLGScheduleEdgeRefresh(void) {} // DD's global ScrollEdgeEffectView mutation is intentionally removed.

static void WCLGTrackTabBar(UITabBar *bar) {
    if (bar) [sGlassBars addObject:bar];

}
// Per-object coalescing: one bar must not evict another bar's pending work.
@interface LYHWGlassPassState : NSObject
@property(nonatomic) BOOL queued;
@property(nonatomic) BOOL inPass;
@property(nonatomic) CFTimeInterval lastPass;
@property(nonatomic) CFTimeInterval budgetStart;
@property(nonatomic) NSUInteger budgetUsed;
@property(nonatomic) CGRect alignmentPlatter;
@property(nonatomic) CGRect alignmentBounds;
@property(nonatomic) BOOL alignmentEstablished;
@property(nonatomic) CFTimeInterval alignmentWindow;
@property(nonatomic) NSUInteger alignmentWrites;
@property(nonatomic) BOOL alignmentSuspended;
@end
@implementation LYHWGlassPassState
@end
static const char kWCLGPassStateKey = 0;
static void WCLGSchedulePass(UITabBar *bar) {
    if (!bar || !WCLGEnabled()) return;
    LYHWGlassPassState *pass = objc_getAssociatedObject(bar, &kWCLGPassStateKey);
    if (!pass) {
        pass = [LYHWGlassPassState new];
        objc_setAssociatedObject(bar, &kWCLGPassStateKey, pass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Writes made by this pass cannot recursively enqueue another pass.
    if (pass.queued || pass.inPass) return;
    pass.queued = YES;
    CFTimeInterval wait = MAX(0, kWCLGMinPassInterval - (CACurrentMediaTime() - pass.lastPass));
    if (!WCLGFinite(wait)) wait = kWCLGMinPassInterval;
    __weak UITabBar *weakBar = bar;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        pass.queued = NO;
        UITabBar *b = weakBar;
        if (!b || !WCLGEnabled() || pass.inPass) return;
        CFTimeInterval now = CACurrentMediaTime();
        if (now - pass.budgetStart >= 1.0) { pass.budgetStart = now; pass.budgetUsed = 0; }
        // No self-sustaining retry chain when budget is exhausted.
        if (pass.budgetUsed >= kWCLGMaxPassesPerSecond) return;
        pass.budgetUsed++;
        pass.lastPass = now;
        if (sWCLGLayoutDepth > 0) { WCLGSchedulePass(b); return; }
        pass.inPass = YES;
        @try { LYHWGlassApplyFeatures(b); }
        @catch (NSException *e) { WCLGLog(@"pass exception: %@", e); }
        @finally { pass.inPass = NO; }
    });
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
@interface LYHWGlassBarState : NSObject
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *hiddenValues;
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *backgroundAlphas;
@end
@implementation LYHWGlassBarState
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
// Fail closed: this is a structural fingerprint from the supplied dump, not
// DD's broad class-name/full-width heuristic. Never inspect a list or window.
static BOOL LYHWGlassMatchesBarRect(UIView *view, UITabBar *bar) {
    CGRect r = view.frame, b = bar.bounds;
    return WCLGFiniteRect(r) && WCLGFiniteRect(b) && b.size.width > 1 && b.size.height > 1 &&
        fabs(r.origin.x - b.origin.x) < 1 && fabs(r.origin.y - b.origin.y) < 1 &&
        fabs(r.size.width - b.size.width) < 1 && fabs(r.size.height - b.size.height) < 1;
}
static UIVisualEffectView *LYHWGlassConfirmedBackground(UITabBar *bar, UIView *host) {
    if (host.superview != bar || host.class != UIView.class ||
        !LYHWGlassMatchesBarRect(host, bar) || host.subviews.count != 1 ||
        host.layer.mask || !WCLGFinite(host.layer.cornerRadius) || host.layer.cornerRadius > 0.5) return nil;
    UIView *effect = host.subviews.firstObject;
    if (effect.class != UIVisualEffectView.class || effect.tag != 102289 ||
        !LYHWGlassMatchesBarRect(effect, bar) || effect.layer.mask ||
        !WCLGFinite(effect.layer.cornerRadius) || effect.layer.cornerRadius > 0.5) return nil;
    // Allow only the three effect internals actually present in the dump.
    // Anything else (item, portal, offscreen source, plugin wrapper) disqualifies
    // the entire candidate; no ancestor containing native content is faded.
    NSSet *allowed = [NSSet setWithArray:@[@"_UIVisualEffectBackdropView",
        @"_UIVisualEffectSubview", @"_UIVisualEffectContentView"]];
    if (effect.subviews.count != 3) return nil;
    NSMutableSet *seen = [NSMutableSet set];
    for (UIView *child in effect.subviews) {
        NSString *name = NSStringFromClass(child.class);
        if (![allowed containsObject:name] || [seen containsObject:name] || child.subviews.count ||
            !LYHWGlassMatchesBarRect(child, bar)) return nil;
        [seen addObject:name];
    }
    return (UIVisualEffectView *)effect;
}
static void LYHWGlassRestoreBackground(LYHWGlassBarState *state, UIView *view) {
    NSNumber *alpha = [state.backgroundAlphas objectForKey:view];
    if (!alpha) return;
    // Do not overwrite a newer explicit alpha supplied by WeChat/another plugin.
    if (view.alpha == 0) view.alpha = alpha.doubleValue;
    [state.backgroundAlphas removeObjectForKey:view];
}
static void LYHWGlassApplyBackground(UITabBar *bar, LYHWGlassBarState *state) {
    NSMutableSet<UIView *> *targets = [NSMutableSet set];
    // Require the real floating platter before suppressing WeChat's fallback.
    BOOL hasPlatter = NO;
    for (UIView *sub in bar.subviews) {
        if ([NSStringFromClass(sub.class) isEqualToString:@"UIKit._UITabBarPlatterView"] &&
            WCLGFiniteRect(sub.frame) && !CGRectIsEmpty(sub.frame)) { hasPlatter = YES; break; }
    }
    if (WCLGIsTabBarHookTarget(bar) && bar.window && !bar.hidden && hasPlatter) {
        for (UIView *sub in bar.subviews) {
            UIVisualEffectView *target = LYHWGlassConfirmedBackground(bar, sub);
            if (target) [targets addObject:target];
        }
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (UIView *old in state.backgroundAlphas.keyEnumerator.allObjects) {
        if (![targets containsObject:old]) LYHWGlassRestoreBackground(state, old);
    }
    for (UIView *target in targets) {
        if (![state.backgroundAlphas objectForKey:target])
            [state.backgroundAlphas setObject:@(target.alpha) forKey:target];
        if (target.alpha != 0) target.alpha = 0;
    }
    [CATransaction commit];
}
static CGRect LYHWGlassPlatterRect(UITabBar *bar) {
    for (UIView *sub in bar.subviews) {
        if (![NSStringFromClass(sub.class) isEqualToString:@"UIKit._UITabBarPlatterView"]) continue;
        CGRect r = [sub convertRect:sub.bounds toView:bar];
        if (WCLGFiniteRect(r) && !CGRectIsEmpty(r)) return CGRectIntersection(r, bar.bounds);
    }
    return CGRectNull;
}
// Adopted from uploaded wctabbar: use the live platter grid, not screen width.
// Fail closed on unknown hierarchies/transforms; never move platter/lens/buttons.
static BOOL LYHWGlassBadgeName(NSString *name);
static CGRect LYHWGlassVisibleContent(UIView *root, UIView *item, NSUInteger depth) {
    if (depth > 6) return CGRectNull;
    CGRect result = CGRectNull;
    for (UIView *child in root.subviews) {
        if (child.hidden || child.alpha <= 0.01 || LYHWGlassBadgeName(NSStringFromClass(child.class))) continue;
        CGRect r = CGRectNull;
        BOOL label = [child isKindOfClass:UILabel.class];
        BOOL icon = [child isKindOfClass:UIImageView.class] ||
            [NSStringFromClass(child.class) isEqualToString:@"MMWebImageView"];
        if (icon || label) {
            CGRect ink = child.bounds;
            if (label) {
                // WeChat's label is 98pt wide even when its title is only 24pt.
                // textRect respects alignment/line count and measures actual ink.
                UILabel *title = (UILabel *)child;
                if (!title.text.length && !title.attributedText.length) continue;
                ink = [title textRectForBounds:title.bounds limitedToNumberOfLines:title.numberOfLines];
            }
            r = [child convertRect:ink toView:item];
            if (!WCLGFiniteRect(r) || CGRectIsEmpty(r) || !CGRectContainsRect(item.bounds, r)) continue;
        } else r = LYHWGlassVisibleContent(child, item, depth + 1);
        if (!CGRectIsNull(r) && !CGRectIsEmpty(r)) result = CGRectUnion(result, r);
    }
    return result;
}
static void LYHWGlassResetBarChrome(UITabBar *bar) {
    // Source's reset, with difference checks on every setter, only on MMTabBar.
    if (!bar.translucent) bar.translucent = YES;
    if (bar.opaque) bar.opaque = NO;
    if (WCLGColorAlpha(bar.backgroundColor) > 0.01) bar.backgroundColor = UIColor.clearColor;
    if (bar.layer.backgroundColor && CGColorGetAlpha(bar.layer.backgroundColor) > 0.01)
        bar.layer.backgroundColor = UIColor.clearColor.CGColor;
}
static void LYHWGlassAlignTabBarItems(UITabBar *bar) {
    if (!WCLGIsTabBarHookTarget(bar) || !bar.window || bar.hidden || sWCLGLayoutDepth > 0 ||
        !CGAffineTransformIsIdentity(bar.transform)) return;
    CGRect pf = LYHWGlassPlatterRect(bar), bounds = bar.bounds;
    if (!WCLGFiniteRect(pf) || CGRectIsNull(pf) || CGRectIsEmpty(pf) ||
        !WCLGFiniteRect(bounds) || !CGRectContainsRect(bounds, pf)) return;
    LYHWGlassPassState *pass = objc_getAssociatedObject(bar, &kWCLGPassStateKey);
    if (!pass) return; // Geometry is only legal inside the scheduled pass.
    // Selection/lens motion and sub-point platter shifts are not size changes.
    // Once aligned, do not fight native relayout on every tab selection.
    BOOL sizeChanged = fabs(pass.alignmentPlatter.size.width - pf.size.width) >= 0.5 ||
        fabs(pass.alignmentPlatter.size.height - pf.size.height) >= 0.5 ||
        fabs(pass.alignmentBounds.size.width - bounds.size.width) >= 0.5 ||
        fabs(pass.alignmentBounds.size.height - bounds.size.height) >= 0.5;
    if (pass.alignmentEstablished && !sizeChanged) return;
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    for (UIView *sub in bar.subviews) {
        if (![NSStringFromClass(sub.class) containsString:@"MMTabBarItemView"]) continue;
        if (!CGAffineTransformIsIdentity(sub.transform) || sub.hidden ||
            !WCLGFiniteRect(sub.frame) || CGRectIsEmpty(sub.frame)) return;
        [items addObject:sub];
    }
    // Four real WeChat entries only; duplicates/partial transitions are not guessed.
    if (items.count != 4 || (bar.items.count && bar.items.count != items.count)) return;
    [items sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return a.center.x < b.center.x ? NSOrderedAscending : a.center.x > b.center.x ? NSOrderedDescending : NSOrderedSame;
    }];
    CGPoint targets[4];
    for (NSUInteger i = 0; i < items.count; i++) {
        UIView *item = items[i];
        CGRect content = LYHWGlassVisibleContent(item, item, 0);
        if (CGRectIsNull(content) || CGRectIsEmpty(content) || !WCLGFiniteRect(content)) return;
        CGFloat slot = pf.size.width / items.count;
        if (content.size.width > slot || content.size.height > pf.size.height) return;
        CGPoint current = [item convertPoint:CGPointMake(CGRectGetMidX(item.bounds), CGRectGetMidY(content)) toView:bar];
        CGPoint target = CGPointMake(CGRectGetMinX(pf) + slot * (i + 0.5), CGRectGetMidY(pf));
        CGFloat dx = target.x - current.x, dy = target.y - current.y;
        // Reject corrupt/offscreen geometry before any write; validate all four atomically.
        if (!WCLGFinite(dx) || !WCLGFinite(dy) || fabs(dx) > bounds.size.width / 2 || fabs(dy) > bounds.size.height) return;
        targets[i] = CGPointMake(item.center.x + dx, item.center.y + dy);
        if (!WCLGFinite(targets[i].x) || !WCLGFinite(targets[i].y)) return;
    }
    CFTimeInterval now = CACurrentMediaTime();
    BOOL changed = !CGRectEqualToRect(pass.alignmentPlatter, pf) || !CGRectEqualToRect(pass.alignmentBounds, bounds);
    if (changed) {
        pass.alignmentPlatter = pf; pass.alignmentBounds = bounds;
        pass.alignmentSuspended = NO; pass.alignmentWindow = now; pass.alignmentWrites = 0;
    }
    if (pass.alignmentSuspended) return; // Resume only for a new real bar/platter geometry.
    BOOL needsWrite = NO;
    for (NSUInteger i = 0; i < items.count; i++) {
        UIView *item = items[i];
        if (fabs(item.center.x - targets[i].x) >= 0.5 || fabs(item.center.y - targets[i].y) >= 0.5) needsWrite = YES;
    }
    if (needsWrite) {
        if (now - pass.alignmentWindow >= 1.0) { pass.alignmentWindow = now; pass.alignmentWrites = 0; }
        if (pass.alignmentWrites >= 4) { pass.alignmentSuspended = YES; return; }
        pass.alignmentWrites++;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    LYHWGlassResetBarChrome(bar);
    for (NSUInteger i = 0; i < items.count; i++) {
        UIView *item = items[i];
        // No layoutIfNeeded/setNeedsLayout or geometry writes below half a point.
        if (fabs(item.center.x - targets[i].x) >= 0.5 || fabs(item.center.y - targets[i].y) >= 0.5)
            item.center = targets[i];
    }
    [CATransaction commit];
    pass.alignmentEstablished = YES;
}
// WeChat items include the 40pt safe-area tail (90pt bounds, content ends at
// y=50 in the dump). Use actual icon/title content, never that full-height box.
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

    for (UIView *sub in view.subviews) LYHWGlassStyleItem(state, sub, depth + 1);
}
static void LYHWGlassRestore(LYHWGlassBarState *state) {
    for (UIView *view in state.hiddenValues.keyEnumerator.allObjects) {
        LYHWGlassSetFeatureHidden(state, view, NO);
    }
}
static void LYHWGlassApplyFeatures(UITabBar *bar) {
    LYHWGlassBarState *state = objc_getAssociatedObject(bar, &kGlassState);
    if (!state) {
        state = [LYHWGlassBarState new];
        state.hiddenValues = [NSMapTable weakToStrongObjectsMapTable];
        state.backgroundAlphas = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(bar, &kGlassState, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    LYHWGlassApplyBackground(bar, state);
    if (!bar.window || bar.hidden) { LYHWGlassRestore(state); return; }
    LYHWGlassAlignTabBarItems(bar);
    NSMutableArray *items = [NSMutableArray array];
    LYHWGlassCollectItems(bar, items, 0);
    for (UIView *old in state.hiddenValues.keyEnumerator.allObjects) {
        BOOL belongs = NO;
        for (UIView *item in items) if ([old isDescendantOfView:item]) { belongs = YES; break; }
        if (!belongs) LYHWGlassSetFeatureHidden(state, old, NO);
    }
    for (UIView *item in items) LYHWGlassStyleItem(state, item, 0);
}
void LYHWGlassTabBarRefresh(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        LYHWGlassReadFeatures();
        if (!sWCLGEnabled) return;
        for (UITabBar *bar in sGlassBars) WCLGSchedulePass(bar);
    });
}
static void LYHWGlassInstallWithRetry(int attempt) {
    BOOL ok = WCLGInstallTabBarHooks();
    WCLGInstallTabBarControllerHooks();
    if ((!ok || !sOrigRelayout) && attempt < 10)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ LYHWGlassInstallWithRetry(attempt + 1); });
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
        sWCLGMainBundle = NSBundle.mainBundle;
        // Critical: do not defer the bundle compatibility hooks to the main queue.
        WCLGInstallBundleHooks();
        // MMTabBar classes may already exist: intercept appearance before first construction.
        LYHWGlassInstallWithRetry(0);
    }
}
