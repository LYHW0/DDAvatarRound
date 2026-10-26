// Standalone iOS 26 native glass bar; WeChat 8.0.80 headers verified.
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
// This plugin replaces Objective-C IMPs through libobjc only.
// No dependency on MSHookMessageEx, libsubstrate or a symbol-rebinding loader.
#import "LYHWGlassTabBar.h"
#import "LYHWConfig.h"
static void LQRefreshWC(void);

#define LQLGLog(...) do {} while (0)
#define LQLGInfo(...) NSLog(@"[LQLiquid] " __VA_ARGS__)
static BOOL sLQLGEnabled;
static NSBundle *sLQLGMainBundle;
static NSString *const kLQLGDesignKey = @"UIDesignRequiresCompatibility";
static NSInteger sLQLGLayoutDepth;
static const CFTimeInterval kLQLGMinPassInterval = 0.05;
static const NSUInteger kLQLGMaxPassesPerSecond = 20;
static BOOL LQLGEnabled(void) { return sLQLGEnabled; }
static BOOL LQLGFinite(CGFloat v) { return isfinite(v); }
static BOOL LQLGFiniteRect(CGRect r) {
    return isfinite(r.origin.x) && isfinite(r.origin.y) && isfinite(r.size.width) && isfinite(r.size.height);
}
static CGFloat LQLGColorAlpha(UIColor *c) { return c ? CGColorGetAlpha(c.CGColor) : 0; }
static BOOL LQLGIsIOS26OrLater(void) {
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){26,0,0}];
}
BOOL LYHWGlassTabBarIsActive(void) { return sLQLGEnabled; }
BOOL LYHWGlassTabBarOwnsBottomBar(UIView *view) {
    if (!sLQLGEnabled) return NO;
    for(Class c=object_getClass(view);c;c=class_getSuperclass(c)) {
        if(c==NSClassFromString(@"MMTabBar") || c==NSClassFromString(@"WCTabBarView") || c==UITabBar.class) return YES;
    }
    return NO;
}
static NSUserDefaults *sGlassDefaults;
static BOOL sHideRedDot, sHideBadge;
static void LQLiquidReadFeatures(void) {
    sHideRedDot = [sGlassDefaults boolForKey:@"glassHideRedDot"];
    sHideBadge = [sGlassDefaults boolForKey:@"glassHideBadge"];
}
static NSHashTable<UITabBar *> *sGlassBars;
static void LQLiquidApplyFeatures(UITabBar *bar);
static void LQLGScheduleEdgeRefresh(void) {} // DD's global ScrollEdgeEffectView mutation is intentionally removed.

static void LQLGTrackTabBar(UITabBar *bar) {
    if (bar) [sGlassBars addObject:bar];

}
// Per-object coalescing: one bar must not evict another bar's pending work.
@interface LQLiquidPassState : NSObject
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
@implementation LQLiquidPassState
@end
static const char kLQLGPassStateKey = 0;
static void LQLGSchedulePass(UITabBar *bar) {
    if (!bar || !LQLGEnabled()) return;
    LQLiquidPassState *pass = objc_getAssociatedObject(bar, &kLQLGPassStateKey);
    if (!pass) {
        pass = [LQLiquidPassState new];
        objc_setAssociatedObject(bar, &kLQLGPassStateKey, pass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Writes made by this pass cannot recursively enqueue another pass.
    if (pass.queued || pass.inPass) return;
    pass.queued = YES;
    CFTimeInterval wait = MAX(0, kLQLGMinPassInterval - (CACurrentMediaTime() - pass.lastPass));
    if (!LQLGFinite(wait)) wait = kLQLGMinPassInterval;
    __weak UITabBar *weakBar = bar;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        pass.queued = NO;
        UITabBar *b = weakBar;
        if (!b || !LQLGEnabled() || pass.inPass) return;
        CFTimeInterval now = CACurrentMediaTime();
        if (now - pass.budgetStart >= 1.0) { pass.budgetStart = now; pass.budgetUsed = 0; }
        // No self-sustaining retry chain when budget is exhausted.
        if (pass.budgetUsed >= kLQLGMaxPassesPerSecond) return;
        pass.budgetUsed++;
        pass.lastPass = now;
        if (sLQLGLayoutDepth > 0) { LQLGSchedulePass(b); return; }
        pass.inPass = YES;
        @try { LQLiquidApplyFeatures(b); }
        @catch (NSException *e) { LQLGLog(@"pass exception: %@", e); }
        @finally { pass.inPass = NO; }
    });
}

typedef void (*LQLGObjIMP)(id, SEL);
typedef void (*LQLGObj1IMP)(id, SEL, id);
typedef void (*LQLGBoolIMP)(id, SEL, BOOL);

static BOOL LQLGClassOwnsSelector(Class cls, SEL sel) {
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

static BOOL LQLGHookInstanceMethod(Class cls, SEL sel, IMP replacement, IMP *original) {
	if (!cls || !sel || !replacement) return NO;
	// Never overwrite an original IMP with our own replacement on retry.
	if (original && *original) return YES;

	Method inherited = class_getInstanceMethod(cls, sel);
	if (!inherited) {
		LQLGLog(@"skip %@ on %@: 类层级里没有这个 selector",
				NSStringFromSelector(sel), NSStringFromClass(cls));
		return NO;
	}
	const char *types = method_getTypeEncoding(inherited);
	if (!types) return NO;
    // Only hook the three known ABIs (object getters, void lifecycle/setters).
    unsigned int nargs = method_getNumberOfArguments(inherited);
    char *ret = method_copyReturnType(inherited);
    BOOL valid = ret && ((nargs == 2 && (ret[0] == 'v' || ret[0] == '@')) ||
                         (nargs == 3 && (ret[0] == 'v' || ret[0] == '@')));
    if (ret) free(ret);
    if (!valid) return NO;
    if (nargs == 3) {
        char *arg = method_copyArgumentType(inherited, 2);
        BOOL boolSetter = sel_isEqual(sel, @selector(setHidden:));
        BOOL argValid = arg && (boolSetter ? (arg[0] == 'B' || arg[0] == 'c') : arg[0] == '@');
        if (arg) free(arg);
        if (!argValid) return NO;
    }
	IMP inheritedIMP = method_getImplementation(inherited);
	if (inheritedIMP == replacement) return NO;

	if (LQLGClassOwnsSelector(cls, sel)) {
        // Objective-C-only hook: no external substrate symbol or null trampoline.
        // Publish original first: replacement may run as soon as the IMP changes.
        if (original) *original = inheritedIMP;
        IMP prev = method_setImplementation(inherited, replacement);
        if (original && prev) *original = prev;
		LQLGLog(@"hooked own %@ on %@", NSStringFromSelector(sel), NSStringFromClass(cls));
		return YES;
	}

	if (class_addMethod(cls, sel, replacement, types)) {
		if (original) *original = inheritedIMP;
		LQLGLog(@"added override %@ on %@ (父类未受影响)",
				NSStringFromSelector(sel), NSStringFromClass(cls));
		return YES;
	}

	LQLGLog(@"skip %@ on %@: addMethod failed",
			NSStringFromSelector(sel), NSStringFromClass(cls));
	return NO;
}

// ============================================================
#pragma mark - Hook 目标守卫（找到才缓存，找不到下次重扫）
// ============================================================

static Class LQLGClassNamed(NSString *name, Class *cache) {
	if (cache && *cache) return *cache;
	Class c = NSClassFromString(name);
	if (c && cache) *cache = c;
	return c;
}

static Class sLQLGMMTabBarClass = Nil;
static Class sLQLGMMTabBarControllerClass = Nil;
static Class sLQLGWCNavigationBarClass = Nil;

static BOOL LQLGIsTabBarHookTarget(id obj) {
	if (!obj) return NO;
	Class cls = LQLGClassNamed(@"MMTabBar", &sLQLGMMTabBarClass);
    BOOL mm = NO, ui = NO;
    for (Class actual = object_getClass(obj); actual; actual = class_getSuperclass(actual)) {
        if (actual == cls) mm = YES;
        if (actual == UITabBar.class) ui = YES;
    }
    return mm && ui;
}

static BOOL LQLGIsNavBarHookTarget(id obj) {
	if (!obj) return NO;
	Class cls = LQLGClassNamed(@"WCCustomNavigationBar", &sLQLGWCNavigationBarClass);
	return cls && [obj isKindOfClass:cls];
}

// ============================================================
#pragma mark - MMTabBar 的 hook 实现
// ============================================================

static const char kLQLGLayoutActiveKey = 0;
static LQLGObjIMP  sOrigTabLayout = NULL;
static LQLGObjIMP  sOrigTabDidMoveToWindow = NULL;
static LQLGObjIMP  sOrigTabDidMoveToSuperview = NULL;
static LQLGObj1IMP sOrigTabTraitChange = NULL;
static LQLGBoolIMP sOrigTabSetHidden = NULL;

static LQLGObj1IMP sOrigTabSetStandardAppearance = NULL;
static LQLGObj1IMP sOrigTabSetScrollEdgeAppearance = NULL;
static LQLGObj1IMP sOrigTabSetBackgroundImage = NULL;
static LQLGObj1IMP sOrigTabSetShadowImage = NULL;
static LQLGObj1IMP sOrigTabSetBarTintColor = NULL;
static LQLGObj1IMP sOrigTabSetBackgroundColor = NULL;

// ⚠️ 布局里绝不做写操作：只记深度、只排队
static void LQLGTabLayoutSubviews(id self, SEL _cmd) {
	if ([objc_getAssociatedObject(self, &kLQLGLayoutActiveKey) boolValue]) return;
	objc_setAssociatedObject(self, &kLQLGLayoutActiveKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	sLQLGLayoutDepth++;
	@try {
		if (sOrigTabLayout) sOrigTabLayout(self, _cmd);
	} @finally {
		sLQLGLayoutDepth--;
		objc_setAssociatedObject(self, &kLQLGLayoutActiveKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	if (!LQLGIsTabBarHookTarget(self) || !LQLGEnabled()) return;
	LQLGTrackTabBar((UITabBar *)self);
	LQLGSchedulePass((UITabBar *)self);
}

static void LQLGTabDidMoveToWindow(id self, SEL _cmd) {
	if (sOrigTabDidMoveToWindow) sOrigTabDidMoveToWindow(self, _cmd);
	if (!LQLGIsTabBarHookTarget(self) || !LQLGEnabled()) return;
	LQLGTrackTabBar((UITabBar *)self);
	LQLGSchedulePass((UITabBar *)self);
	LQLGScheduleEdgeRefresh();
}

static void LQLGTabDidMoveToSuperview(id self, SEL _cmd) {
	if (sOrigTabDidMoveToSuperview) sOrigTabDidMoveToSuperview(self, _cmd);
	if (!LQLGIsTabBarHookTarget(self) || !LQLGEnabled()) return;
	LQLGSchedulePass((UITabBar *)self);
}

static void LQLGTabTraitCollectionDidChange(id self, SEL _cmd, id previous) {
	if (sOrigTabTraitChange) sOrigTabTraitChange(self, _cmd, previous);
	if (!LQLGIsTabBarHookTarget(self) || !LQLGEnabled()) return;
	LQLGSchedulePass((UITabBar *)self);
}

static void LQLGTabSetHidden(id self, SEL _cmd, BOOL hidden) {
	if (sOrigTabSetHidden) sOrigTabSetHidden(self, _cmd, hidden);
	if (!LQLGIsTabBarHookTarget(self) || !LQLGEnabled()) return;
	LQLGScheduleEdgeRefresh();
	LQLGSchedulePass((UITabBar *)self);
}

// —— 吞掉微信的 appearance 覆盖，保留系统默认（浮动玻璃的来源）——
static void LQLGTabSetStandardAppearance(id self, SEL _cmd, id appearance) {
	if (LQLGIsTabBarHookTarget(self) && LQLGEnabled()) return;
	if (sOrigTabSetStandardAppearance) sOrigTabSetStandardAppearance(self, _cmd, appearance);
}

static void LQLGTabSetScrollEdgeAppearance(id self, SEL _cmd, id appearance) {
	if (LQLGIsTabBarHookTarget(self) && LQLGEnabled()) return;
	if (sOrigTabSetScrollEdgeAppearance) sOrigTabSetScrollEdgeAppearance(self, _cmd, appearance);
}

static void LQLGTabSetBackgroundImage(id self, SEL _cmd, id image) {
	if (LQLGIsTabBarHookTarget(self) && LQLGEnabled()) return;
	if (sOrigTabSetBackgroundImage) sOrigTabSetBackgroundImage(self, _cmd, image);
}

static void LQLGTabSetShadowImage(id self, SEL _cmd, id image) {
	if (LQLGIsTabBarHookTarget(self) && LQLGEnabled()) return;
	if (sOrigTabSetShadowImage) sOrigTabSetShadowImage(self, _cmd, image);
}

static void LQLGTabSetBarTintColor(id self, SEL _cmd, id color) {
	if (LQLGIsTabBarHookTarget(self) && LQLGEnabled()) return;
	if (sOrigTabSetBarTintColor) sOrigTabSetBarTintColor(self, _cmd, color);
}

// 背景色：只挡不透明的（并且只挡微信底栏，别的视图一律放行）
static void LQLGTabSetBackgroundColor(id self, SEL _cmd, UIColor *color) {
	if (LQLGIsTabBarHookTarget(self) && LQLGEnabled()) {
		if (color && LQLGColorAlpha(color) > 0.01) return;
	}
	if (sOrigTabSetBackgroundColor) sOrigTabSetBackgroundColor(self, _cmd, color);
}

static BOOL LQLGInstallTabBarHooks(void) {
	static BOOL installed = NO;
	if (installed) return YES;

	Class cls = LQLGClassNamed(@"MMTabBar", &sLQLGMMTabBarClass);
	if (!cls) return NO;

	LQLGHookInstanceMethod(cls, @selector(layoutSubviews), (IMP)&LQLGTabLayoutSubviews, (IMP *)&sOrigTabLayout);
	LQLGHookInstanceMethod(cls, @selector(didMoveToWindow), (IMP)&LQLGTabDidMoveToWindow, (IMP *)&sOrigTabDidMoveToWindow);
	LQLGHookInstanceMethod(cls, @selector(didMoveToSuperview), (IMP)&LQLGTabDidMoveToSuperview, (IMP *)&sOrigTabDidMoveToSuperview);
	LQLGHookInstanceMethod(cls, @selector(traitCollectionDidChange:), (IMP)&LQLGTabTraitCollectionDidChange, (IMP *)&sOrigTabTraitChange);
	LQLGHookInstanceMethod(cls, @selector(setHidden:), (IMP)&LQLGTabSetHidden, (IMP *)&sOrigTabSetHidden);

	LQLGHookInstanceMethod(cls, NSSelectorFromString(@"setStandardAppearance:"),
						   (IMP)&LQLGTabSetStandardAppearance, (IMP *)&sOrigTabSetStandardAppearance);
	LQLGHookInstanceMethod(cls, NSSelectorFromString(@"setScrollEdgeAppearance:"),
						   (IMP)&LQLGTabSetScrollEdgeAppearance, (IMP *)&sOrigTabSetScrollEdgeAppearance);
	LQLGHookInstanceMethod(cls, NSSelectorFromString(@"setBackgroundImage:"),
						   (IMP)&LQLGTabSetBackgroundImage, (IMP *)&sOrigTabSetBackgroundImage);
	LQLGHookInstanceMethod(cls, NSSelectorFromString(@"setShadowImage:"),
						   (IMP)&LQLGTabSetShadowImage, (IMP *)&sOrigTabSetShadowImage);
	LQLGHookInstanceMethod(cls, NSSelectorFromString(@"setBarTintColor:"),
						   (IMP)&LQLGTabSetBarTintColor, (IMP *)&sOrigTabSetBarTintColor);
	LQLGHookInstanceMethod(cls, @selector(setBackgroundColor:),
						   (IMP)&LQLGTabSetBackgroundColor, (IMP *)&sOrigTabSetBackgroundColor);

	installed = YES;
	LQLGInfo(@"MMTabBar hook 安装完成");
	return YES;
}

// ============================================================
#pragma mark - MMTabBarController.relayoutButtons:
// ============================================================

// WeChat 8.0.80: - (void)relayoutButtons:(id)a0 (NOT BOOL).
typedef void (*LQLGRelayoutIMP)(id, SEL, id);
static LQLGRelayoutIMP sOrigRelayout = NULL;

static void LQLGRelayoutButtonsHook(id self, SEL _cmd, id sender) {
	if (sOrigRelayout) sOrigRelayout(self, _cmd, sender);
	if (!LQLGEnabled()) return;
	@try {
        SEL custom = NSSelectorFromString(@"customTabBar");
        id candidate = [self respondsToSelector:custom] ? ((id(*)(id,SEL))objc_msgSend)(self,custom) : nil;
		UITabBar *bar = LQLGIsTabBarHookTarget(candidate) ? candidate : [(UITabBarController *)self tabBar];
		if (!bar) return;
		LQLGSchedulePass(bar);
	} @catch (NSException *e) {
		LQLGLog(@"relayoutButtons exception: %@", e);
	}
}

static void LQLGInstallTabBarControllerHooks(void) {
	static BOOL installed = NO;
	if (installed) return;
	Class cls = LQLGClassNamed(@"MMTabBarController", &sLQLGMMTabBarControllerClass);
	if (!cls) return;
	SEL sel = NSSelectorFromString(@"relayoutButtons:");
	if (!sel || !class_getInstanceMethod(cls, sel)) return;
	installed = LQLGHookInstanceMethod(cls, sel, (IMP)&LQLGRelayoutButtonsHook, (IMP *)&sOrigRelayout);
}

static const void *kLQLGPatchedInfoKey = &kLQLGPatchedInfoKey;

static NSDictionary *LQLGPatchedInfoDictionary(NSDictionary *src) {
	if (!src) return src;

	NSDictionary *patched = objc_getAssociatedObject(src, kLQLGPatchedInfoKey);
	if (patched) return patched;

	@try {
		NSMutableDictionary *m = [src mutableCopy];
		if (!m) return src;
		m[kLQLGDesignKey] = @NO;
		patched = [m copy];
		if (patched) {
			objc_setAssociatedObject(src, kLQLGPatchedInfoKey, patched, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
	} @catch (NSException *e) {
		LQLGLog(@"patch info dictionary exception: %@", e);
	}
	return patched ?: src;
}

typedef id (*LQLGObjKeyIMP)(id, SEL, id);
typedef id (*LQLGObjRetIMP)(id, SEL);

static LQLGObjKeyIMP sOrigBundleObjectForInfoKey = NULL;
static LQLGObjRetIMP sOrigBundleInfoDictionary = NULL;
static LQLGObjRetIMP sOrigBundleLocalizedInfoDictionary = NULL;

static BOOL LQLGIsMainBundleSelf(id self) {
	return (sLQLGMainBundle && self == sLQLGMainBundle);
}

static id LQLGBundleObjectForInfoDictionaryKey(id self, SEL _cmd, NSString *key) {
	if (LQLGEnabled() && LQLGIsMainBundleSelf(self) && [key isEqualToString:kLQLGDesignKey]) {
		return @NO;
	}
	return sOrigBundleObjectForInfoKey ? sOrigBundleObjectForInfoKey(self, _cmd, key) : nil;
}

static id LQLGBundleInfoDictionary(id self, SEL _cmd) {
	id d = sOrigBundleInfoDictionary ? sOrigBundleInfoDictionary(self, _cmd) : nil;
	if (!LQLGEnabled() || !d || ![d isKindOfClass:[NSDictionary class]] || !LQLGIsMainBundleSelf(self)) return d;
	if ([d objectForKey:kLQLGDesignKey] == nil) return d;
	return LQLGPatchedInfoDictionary(d);
}

static id LQLGBundleLocalizedInfoDictionary(id self, SEL _cmd) {
	id d = sOrigBundleLocalizedInfoDictionary ? sOrigBundleLocalizedInfoDictionary(self, _cmd) : nil;
	if (!LQLGEnabled() || !d || ![d isKindOfClass:[NSDictionary class]] || !LQLGIsMainBundleSelf(self)) return d;
	if ([d objectForKey:kLQLGDesignKey] == nil) return d;
	return LQLGPatchedInfoDictionary(d);
}

static void LQLGInstallBundleHooks(void) {
	static BOOL installed = NO;
	if (installed) return;
	Class cls = [NSBundle class];
	LQLGHookInstanceMethod(cls, @selector(objectForInfoDictionaryKey:),
						   (IMP)&LQLGBundleObjectForInfoDictionaryKey, (IMP *)&sOrigBundleObjectForInfoKey);
	LQLGHookInstanceMethod(cls, @selector(infoDictionary),
						   (IMP)&LQLGBundleInfoDictionary, (IMP *)&sOrigBundleInfoDictionary);
	LQLGHookInstanceMethod(cls, @selector(localizedInfoDictionary),
						   (IMP)&LQLGBundleLocalizedInfoDictionary, (IMP *)&sOrigBundleLocalizedInfoDictionary);
	installed = YES;
}


#pragma mark - Scoped feature state (no system lens or platter mutation)
static char kGlassState;
@interface LQLiquidBarState : NSObject
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *hiddenValues;
@property(nonatomic, strong) NSMapTable<UIView *, NSNumber *> *backgroundAlphas;
@end
@implementation LQLiquidBarState
@end

// Traverse only to locate actual item/button roots; no setters on intervening containers.
static void LQLiquidCollectItems(UIView *view, NSMutableArray<UIView *> *items, NSUInteger depth) {
    if (depth > 12) return;
    for (UIView *sub in view.subviews) {
        NSString *name = NSStringFromClass(sub.class);
        BOOL target = [name containsString:@"MMTabBarItemView"] ||
            [name containsString:@"UITabBarButton"] || [name containsString:@"UITabButton"];
        if (target) [items addObject:sub];
        else LQLiquidCollectItems(sub, items, depth + 1);
    }
}
// Fail closed: this is a structural fingerprint from the supplied dump, not
// DD's broad class-name/full-width heuristic. Never inspect a list or window.
static BOOL LQLiquidMatchesBarRect(UIView *view, UITabBar *bar) {
    CGRect r = view.frame, b = bar.bounds;
    return LQLGFiniteRect(r) && LQLGFiniteRect(b) && b.size.width > 1 && b.size.height > 1 &&
        fabs(r.origin.x - b.origin.x) < 1 && fabs(r.origin.y - b.origin.y) < 1 &&
        fabs(r.size.width - b.size.width) < 1 && fabs(r.size.height - b.size.height) < 1;
}
static UIVisualEffectView *LQLiquidConfirmedBackground(UITabBar *bar, UIView *host) {
    if (host.superview != bar || host.class != UIView.class ||
        !LQLiquidMatchesBarRect(host, bar) || host.subviews.count != 1 ||
        host.layer.mask || !LQLGFinite(host.layer.cornerRadius) || host.layer.cornerRadius > 0.5) return nil;
    UIView *effect = host.subviews.firstObject;
    if (effect.class != UIVisualEffectView.class || effect.tag != 102289 ||
        !LQLiquidMatchesBarRect(effect, bar) || effect.layer.mask ||
        !LQLGFinite(effect.layer.cornerRadius) || effect.layer.cornerRadius > 0.5) return nil;
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
            !LQLiquidMatchesBarRect(child, bar)) return nil;
        [seen addObject:name];
    }
    return (UIVisualEffectView *)effect;
}
static void LQLiquidRestoreBackground(LQLiquidBarState *state, UIView *view) {
    NSNumber *alpha = [state.backgroundAlphas objectForKey:view];
    if (!alpha) return;
    // Do not overwrite a newer explicit alpha supplied by WeChat/another plugin.
    if (view.alpha == 0) view.alpha = alpha.doubleValue;
    [state.backgroundAlphas removeObjectForKey:view];
}
static void LQLiquidApplyBackground(UITabBar *bar, LQLiquidBarState *state) {
    NSMutableSet<UIView *> *targets = [NSMutableSet set];
    // Require the real floating platter before suppressing WeChat's fallback.
    BOOL hasPlatter = NO;
    for (UIView *sub in bar.subviews) {
        if ([NSStringFromClass(sub.class) isEqualToString:@"UIKit._UITabBarPlatterView"] &&
            LQLGFiniteRect(sub.frame) && !CGRectIsEmpty(sub.frame)) { hasPlatter = YES; break; }
    }
    if (LQLGIsTabBarHookTarget(bar) && bar.window && !bar.hidden && hasPlatter) {
        for (UIView *sub in bar.subviews) {
            UIVisualEffectView *target = LQLiquidConfirmedBackground(bar, sub);
            if (target) [targets addObject:target];
        }
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (UIView *old in state.backgroundAlphas.keyEnumerator.allObjects) {
        if (![targets containsObject:old]) LQLiquidRestoreBackground(state, old);
    }
    for (UIView *target in targets) {
        if (![state.backgroundAlphas objectForKey:target])
            [state.backgroundAlphas setObject:@(target.alpha) forKey:target];
        if (target.alpha != 0) target.alpha = 0;
    }
    [CATransaction commit];
}
static CGRect LQLiquidPlatterRect(UITabBar *bar) {
    for (UIView *sub in bar.subviews) {
        if (![NSStringFromClass(sub.class) isEqualToString:@"UIKit._UITabBarPlatterView"]) continue;
        CGRect r = [sub convertRect:sub.bounds toView:bar];
        if (LQLGFiniteRect(r) && !CGRectIsEmpty(r)) return CGRectIntersection(r, bar.bounds);
    }
    return CGRectNull;
}
// Adopted from uploaded wctabbar: use the live platter grid, not screen width.
// Fail closed on unknown hierarchies/transforms; never move platter/lens/buttons.
static BOOL LQLiquidBadgeName(NSString *name);
static CGRect LQLiquidVisibleContent(UIView *root, UIView *item, NSUInteger depth) {
    if (depth > 6) return CGRectNull;
    CGRect result = CGRectNull;
    for (UIView *child in root.subviews) {
        if (child.hidden || child.alpha <= 0.01 || LQLiquidBadgeName(NSStringFromClass(child.class))) continue;
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
            if (!LQLGFiniteRect(r) || CGRectIsEmpty(r) || !CGRectContainsRect(item.bounds, r)) continue;
        } else r = LQLiquidVisibleContent(child, item, depth + 1);
        if (!CGRectIsNull(r) && !CGRectIsEmpty(r)) result = CGRectUnion(result, r);
    }
    return result;
}
static void LQLiquidResetBarChrome(UITabBar *bar) {
    // Source's reset, with difference checks on every setter, only on MMTabBar.
    if (!bar.translucent) bar.translucent = YES;
    if (bar.opaque) bar.opaque = NO;
    if (LQLGColorAlpha(bar.backgroundColor) > 0.01) bar.backgroundColor = UIColor.clearColor;
    if (bar.layer.backgroundColor && CGColorGetAlpha(bar.layer.backgroundColor) > 0.01)
        bar.layer.backgroundColor = UIColor.clearColor.CGColor;
}
static void LQLiquidAlignTabBarItems(UITabBar *bar) {
    if (!LQLGIsTabBarHookTarget(bar) || !bar.window || bar.hidden || sLQLGLayoutDepth > 0 ||
        !CGAffineTransformIsIdentity(bar.transform)) return;
    CGRect pf = LQLiquidPlatterRect(bar), bounds = bar.bounds;
    if (!LQLGFiniteRect(pf) || CGRectIsNull(pf) || CGRectIsEmpty(pf) ||
        !LQLGFiniteRect(bounds) || !CGRectContainsRect(bounds, pf)) return;
    LQLiquidPassState *pass = objc_getAssociatedObject(bar, &kLQLGPassStateKey);
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
            !LQLGFiniteRect(sub.frame) || CGRectIsEmpty(sub.frame)) return;
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
        CGRect content = LQLiquidVisibleContent(item, item, 0);
        if (CGRectIsNull(content) || CGRectIsEmpty(content) || !LQLGFiniteRect(content)) return;
        CGFloat slot = pf.size.width / items.count;
        if (content.size.width > slot || content.size.height > pf.size.height) return;
        CGPoint current = [item convertPoint:CGPointMake(CGRectGetMidX(item.bounds), CGRectGetMidY(content)) toView:bar];
        CGPoint target = CGPointMake(CGRectGetMinX(pf) + slot * (i + 0.5), CGRectGetMidY(pf));
        CGFloat dx = target.x - current.x, dy = target.y - current.y;
        // Reject corrupt/offscreen geometry before any write; validate all four atomically.
        if (!LQLGFinite(dx) || !LQLGFinite(dy) || fabs(dx) > bounds.size.width / 2 || fabs(dy) > bounds.size.height) return;
        targets[i] = CGPointMake(item.center.x + dx, item.center.y + dy);
        if (!LQLGFinite(targets[i].x) || !LQLGFinite(targets[i].y)) return;
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
    LQLiquidResetBarChrome(bar);
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
static BOOL LQLiquidBadgeName(NSString *name) {
    NSString *lower = name.lowercaseString;
    return [lower containsString:@"badge"] || [lower containsString:@"reddot"] ||
        [lower containsString:@"red_dot"] || [lower containsString:@"newmessage"] ||
        [lower containsString:@"unread"];
}
static NSString *LQLiquidBadgeText(UIView *view, NSUInteger depth) {
    if (depth > 5) return nil;
    if ([view isKindOfClass:UILabel.class]) return ((UILabel *)view).text;
    if ([view isKindOfClass:UIButton.class]) return ((UIButton *)view).currentTitle;
    for (UIView *sub in view.subviews) {
        NSString *text = LQLiquidBadgeText(sub, depth + 1);
        if (text.length) return text;
    }
    return nil;
}
static void LQLiquidSetFeatureHidden(LQLiquidBarState *state, UIView *view, BOOL hide) {
    NSNumber *saved = [state.hiddenValues objectForKey:view];
    if (hide) {
        if (!saved) [state.hiddenValues setObject:@(view.hidden) forKey:view];
        if (!view.hidden) view.hidden = YES;
    } else if (saved) {
        if (view.hidden != saved.boolValue) view.hidden = saved.boolValue;
        [state.hiddenValues removeObjectForKey:view];
    }
}
static void LQLiquidStyleItem(LQLiquidBarState *state, UIView *view, NSUInteger depth) {
    if (depth > 10) return;
    NSString *name = NSStringFromClass(view.class);
    if (LQLiquidBadgeName(name)) {
        NSString *text = LQLiquidBadgeText(view, 0);
        // Numeric badges (including 99+) and text badges are not pure red dots.
        BOOL dot = !text.length;
        LQLiquidSetFeatureHidden(state, view, dot ? sHideRedDot : sHideBadge);
        return; // Never hide a badge's UILabel as tab title.
    }

    for (UIView *sub in view.subviews) LQLiquidStyleItem(state, sub, depth + 1);
}
static void LQLiquidRestore(LQLiquidBarState *state) {
    for (UIView *view in state.hiddenValues.keyEnumerator.allObjects) {
        LQLiquidSetFeatureHidden(state, view, NO);
    }
}
static void LQLiquidApplyFeatures(UITabBar *bar) {
    LQLiquidBarState *state = objc_getAssociatedObject(bar, &kGlassState);
    if (!state) {
        state = [LQLiquidBarState new];
        state.hiddenValues = [NSMapTable weakToStrongObjectsMapTable];
        state.backgroundAlphas = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(bar, &kGlassState, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    LQLiquidApplyBackground(bar, state);
    if (!bar.window || bar.hidden) { LQLiquidRestore(state); return; }
    LQLiquidAlignTabBarItems(bar);
    NSMutableArray *items = [NSMutableArray array];
    LQLiquidCollectItems(bar, items, 0);
    for (UIView *old in state.hiddenValues.keyEnumerator.allObjects) {
        BOOL belongs = NO;
        for (UIView *item in items) if ([old isDescendantOfView:item]) { belongs = YES; break; }
        if (!belongs) LQLiquidSetFeatureHidden(state, old, NO);
    }
    for (UIView *item in items) LQLiquidStyleItem(state, item, 0);
}
void LYHWGlassTabBarRefresh(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        LQLiquidReadFeatures();
        if (!sLQLGEnabled) return;
        for (UITabBar *bar in sGlassBars) LQLGSchedulePass(bar);
        LQRefreshWC();
    });
}
#include "WCBridge.inc"

static void LQLiquidInstallWithRetry(int attempt) {
    LQInstallWCBridge();
    BOOL ok = LQLGInstallTabBarHooks();
    LQLGInstallTabBarControllerHooks();
    if ((!ok || !sOrigRelayout) && attempt < 10)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ LQLiquidInstallWithRetry(attempt + 1); });
}
__attribute__((constructor)) static void LQLiquidInitialize(void) {
    @autoreleasepool {
        // Independent preferences; no dependency on the corner plugin.
        sGlassDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.lyhw.LYHW"];
        sLQLGEnabled = LQLGIsIOS26OrLater() && [sGlassDefaults boolForKey:@"glassTabBarEnabled"]; // Standalone: injection enables it, no master setting needed.
        LQLiquidReadFeatures();
        [[NSNotificationCenter defaultCenter] addObserverForName:LYHWSettingsChangedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { LYHWGlassTabBarRefresh(); }];
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { LYHWGlassTabBarRefresh(); }];
        if (!sLQLGEnabled) return; // Absolutely no hooks installed when disabled at launch.
        sGlassBars = [NSHashTable weakObjectsHashTable];
        sLQLGMainBundle = NSBundle.mainBundle;
        // Critical: do not defer the bundle compatibility hooks to the main queue.
        LQLGInstallBundleHooks();
        // MMTabBar classes may already exist: intercept appearance before first construction.
        LQLiquidInstallWithRetry(0);
    }
}
