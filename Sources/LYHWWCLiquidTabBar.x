// ============================================================================
//  WCLiquidTabBar.x  —  微信底栏「iOS 26 原生 Liquid Glass 浮动胶囊」
//  逆向自 com.x.wctabbar v1.0.1（作者 Riee）的 wctabbar.dylib，并按 8.0.80 /
//  iOS 26 的实际结构重写了稳定性相关的部分。
//  ---------------------------------------------------------------------------
//  这一版和原版的三处关键差别（都是闪退 / 卡顿的直接原因）：
//
//  1. 不再从底栏上 removeFromSuperview 任何系统视图。
//     微信 8.0.80 会把底栏背景层缓存在自己的 ivar 里，视图被摘掉后内部还留着引用，
//     下一次布局就是野指针 —— 表现正是"启动 1.5 秒后闪退"。
//     这里改成 hidden / alpha=0 / 关交互，视觉一致，但不动视图持有关系。
//
//  2. 所有几何改动都不在 layoutSubviews 里当场做。
//     原版在 layout 中途 setCenter / removeFromSuperview，会触发
//     layout → 改动 → layout 的递归，轻则掉帧，重则主线程卡死。
//     现在统一 dispatch 到下一轮主队列，同一个底栏只排一次。
//
//  3. 设计开关（UIDesignRequiresCompatibility）在 ctor 里就抹掉，
//     而不是等 1.5 秒 —— 那时候 UIKit 早就把设计模式定死了，晚了不但没用，
//     还给 NSBundle 挂上全局 hook，中途改 bundle 信息很容易出连锁问题。
//
//  编译：Theos，ARC，arm64。入口：ZKInstallLiquidCompatBypass() + ZKInstallLiquidTabBar()
// ============================================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "LYHWConfig.h"

// 自己在 Tweak.x 里调安装，不生成 %ctor
#define ZK_LIQUID_TABBAR_EXTERNAL_CTOR 1

// ----------------------------------------------------------------------------
// 0. 常量
// ----------------------------------------------------------------------------

// Info.plist 里让 App 退回旧设计（非 Liquid Glass）的那把开关
static NSString *const kZKCompatKey    = @"UIDesignRequiresCompatibility";

// iOS 26 的滚动边缘效果视图（Swift 类，两种写法都试）
static NSString *const kZKEdgeSwift    = @"UIKit.ScrollEdgeEffectView";
static NSString *const kZKEdgeMangled  = @"_TtC5UIKit20ScrollEdgeEffectView";

// 子视图分类：靠类名子串识别，微信改类名时只需要改这里
static NSString *const kZKNamePlatter  = @"Platter";
static NSString *const kZKNameItemView = @"MMTabBarItemView";
static NSString *const kZKNameKind3[]  = {
    @"LiquidLens", @"TabBarButton", @"ItemView", @"Container", @"_UITabButton"
};

enum {
    ZKViewKindUnknown    = 0,
    ZKViewKindPlatter    = 1,   // 玻璃胶囊底板：定位基准
    ZKViewKindItem       = 2,   // tab item 容器：要重新均匀排布
    ZKViewKindButton     = 3,   // 按钮 / 图标 / 高光镜片
    ZKViewKindBackground = 4    // 铺满整条 bar 的背景层：藏掉
};

static const CGFloat kZKAlphaEpsilon = 0.01;
static const CGFloat kZKTopBarHeight = 44.0;
static const CGFloat kZKTopTolerance = 1.0;

// ----------------------------------------------------------------------------
// 1. 全局状态
// ----------------------------------------------------------------------------

static NSMapTable    *gZKKindCache;
static dispatch_once_t gZKKindOnce;

static NSHashTable   *gZKEdgeViews;
static dispatch_once_t gZKEdgeOnce;

static BOOL           gZKInSetHidden = NO;   // 防 setHidden: 递归
static BOOL           gZKInRelayout  = NO;   // 防 layout 递归
static UIView *__weak gZKLastBar;
static char kZKEdgeHiddenAssociationKey;
static const void *const kZKEdgeHiddenKey = &kZKEdgeHiddenAssociationKey;
static char kZKPendingKey;                   // 本轮已排过 relayout

// ----------------------------------------------------------------------------
// 2. 微信侧的类
// ----------------------------------------------------------------------------
@interface MMTabBar : UITabBar @end
@interface MMTabBarController : UIViewController
@property (nonatomic, readonly, strong) UITabBar *tabBar;
@end

// ----------------------------------------------------------------------------
// 3. 设计模式开关（ctor 期安装）
// ----------------------------------------------------------------------------

static id            (*zkOrig_objectForInfoDictionaryKey)(id, SEL, NSString *);
static NSDictionary *(*zkOrig_infoDictionary)(id, SEL);
static BOOL           sZKCompatInstalled = NO;

static BOOL ZKIsMainBundle(id bundle) {
    if (!bundle) return NO;
    if (![bundle isKindOfClass:[NSBundle class]]) return NO;
    return bundle == [NSBundle mainBundle];
}

static id zk_objectForInfoDictionaryKey(id self, SEL _cmd, NSString *key) {
    if (key && [key isEqualToString:kZKCompatKey] && ZKIsMainBundle(self)) {
        return (__bridge id)kCFBooleanFalse;
    }
    return zkOrig_objectForInfoDictionaryKey ? zkOrig_objectForInfoDictionaryKey(self, _cmd, key) : nil;
}

// 只在主 bundle、且原字典里确实带这个键时才替换，并且只建一次副本。
// 原版每次调用都 mutableCopy + 加锁，infoDictionary 是启动期极高频调用，
// 那套写法既慢又容易在锁里撞上重入。
static NSDictionary *zk_infoDictionary(id self, SEL _cmd) {
    NSDictionary *dict = zkOrig_infoDictionary ? zkOrig_infoDictionary(self, _cmd) : nil;
    if (![dict isKindOfClass:[NSDictionary class]]) return dict;
    if (!ZKIsMainBundle(self)) return dict;
    if (dict[kZKCompatKey] == nil) return dict;

    static NSDictionary *sPatched = nil;
    if (!sPatched) {
        NSMutableDictionary *m = [dict mutableCopy];
        if (m) {
            m[kZKCompatKey] = @NO;
            sPatched = [m copy];
        }
    }
    return sPatched ?: dict;
}

void ZKInstallLiquidCompatBypass(void) {
    if (sZKCompatInstalled) return;

    // 低版本没有 Liquid Glass，别乱改设计开关
    if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion < 26) return;

    // 只在液态底栏开启时才抹开关；关着就完全不碰 NSBundle
    @try {
        if (![LYHWConfig shared].liquidTabBarEnabled) return;
    } @catch (__unused NSException *e) {
        return;
    }

    sZKCompatInstalled = YES;

    Class cls = objc_getClass("NSBundle");
    if (!cls) return;

    Method mKey = class_getInstanceMethod(cls, @selector(objectForInfoDictionaryKey:));
    if (mKey) {
        IMP old = method_setImplementation(mKey, (IMP)zk_objectForInfoDictionaryKey);
        if (old && old != (IMP)zk_objectForInfoDictionaryKey) {
            zkOrig_objectForInfoDictionaryKey = (id (*)(id, SEL, NSString *))old;
        }
    }
    Method mDict = class_getInstanceMethod(cls, @selector(infoDictionary));
    if (mDict) {
        IMP old = method_setImplementation(mDict, (IMP)zk_infoDictionary);
        if (old && old != (IMP)zk_infoDictionary) {
            zkOrig_infoDictionary = (NSDictionary *(*)(id, SEL))old;
        }
    }
    NSLog(@"[wctabbar] design compatibility bypass installed");
}

// ----------------------------------------------------------------------------
// 4. 工具
// ----------------------------------------------------------------------------

static void ZKEnsureKindCache(void) {
    dispatch_once(&gZKKindOnce, ^{
        gZKKindCache = [NSMapTable strongToStrongObjectsMapTable];
    });
}

static NSHashTable *ZKEdgeViewTable(void) {
    dispatch_once(&gZKEdgeOnce, ^{
        gZKEdgeViews = [NSHashTable weakObjectsHashTable];
    });
    return gZKEdgeViews;
}

// 这颗子树里是不是装着 tab 内容（底板 / item）。装着就绝不当背景处理。
static BOOL ZKContainsTabContent(UIView *view) {
    if (!view) return NO;
    for (UIView *sub in view.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:kZKNamePlatter] || [name containsString:kZKNameItemView]) return YES;
        if (sub.subviews.count && ZKContainsTabContent(sub)) return YES;
    }
    return NO;
}

// 背景层判定：只认「明显是背景」的类，不再用 bundleForClass 一刀切。
// 原版把所有主包里的类都当背景，结果会误伤 item 容器以外的正常内容视图。
static BOOL ZKLooksLikeBarBackground(UIView *view) {
    if (!view) return NO;
    NSString *name = NSStringFromClass([view class]);
    static NSString *const marks[] = { @"Background", @"Shadow", @"Divider", @"Separator", @"HairLine" };
    for (size_t i = 0; i < sizeof(marks) / sizeof(marks[0]); i++) {
        if ([name containsString:marks[i]]) return YES;
    }
    if ([view isKindOfClass:[UIVisualEffectView class]]) return YES;
    if ([name isEqualToString:@"UIView"]) return YES;
    return NO;
}

// ----------------------------------------------------------------------------
// 5. 子视图分类（带缓存）
// ----------------------------------------------------------------------------

static NSUInteger ZKKindOfView(UIView *view) {
    if (!view) return ZKViewKindUnknown;
    Class cls = [view class];
    if (!cls) return ZKViewKindUnknown;

    ZKEnsureKindCache();
    NSNumber *cached = [gZKKindCache objectForKey:cls];
    if (cached) return [cached unsignedIntegerValue];

    NSUInteger kind = ZKViewKindUnknown;
    NSString *name = NSStringFromClass(cls);

    if ([name containsString:kZKNamePlatter]) {
        kind = ZKViewKindPlatter;
    } else if ([name containsString:kZKNameItemView]) {
        kind = ZKViewKindItem;
    } else {
        BOOL isButton = NO;
        for (size_t i = 0; i < sizeof(kZKNameKind3) / sizeof(kZKNameKind3[0]); i++) {
            if ([name containsString:kZKNameKind3[i]]) { isButton = YES; break; }
        }
        if (isButton) kind = ZKViewKindButton;
        else if (ZKLooksLikeBarBackground(view)) kind = ZKViewKindBackground;
    }

    [gZKKindCache setObject:@(kind) forKey:cls];
    return kind;
}

// ----------------------------------------------------------------------------
// 6. 底栏本体做成全透明
// ----------------------------------------------------------------------------

static void ZKApplyTabBarTransparency(id object) {
    if (!object) return;
    if (![object isKindOfClass:[UITabBar class]]) return;
    UITabBar *bar = (UITabBar *)object;

    BOOL hasVisibleBackground = NO;
    UIColor *bg = bar.backgroundColor;
    if (bg) {
        CGColorRef c = [bg CGColor];
        if (c && CGColorGetAlpha(c) > kZKAlphaEpsilon) hasVisibleBackground = YES;
    }
    if (!hasVisibleBackground) {
        CGColorRef layerColor = bar.layer.backgroundColor;
        if (layerColor && CGColorGetAlpha(layerColor) > kZKAlphaEpsilon) hasVisibleBackground = YES;
    }
    if (bar.isTranslucent && !bar.isOpaque && !hasVisibleBackground) return;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [bar setTranslucent:YES];
    [bar setOpaque:NO];
    [bar setBackgroundColor:[UIColor clearColor]];
    bar.layer.backgroundColor = [[UIColor clearColor] CGColor];
    [CATransaction commit];
}

// ----------------------------------------------------------------------------
// 7. 藏背景层 + 把 item 均匀摆进玻璃胶囊（不在 layout 里当场执行）
// ----------------------------------------------------------------------------

static void ZKRelayoutTabBarNow(UIView *bar) {
    if (!bar || gZKInRelayout) return;
    if (![bar window]) return;                       // 已经离屏的底栏不处理

    CGRect barBounds = bar.bounds;
    if (barBounds.size.width < 1.0 || barBounds.size.height < 1.0) return;

    gZKInRelayout = YES;
    @try {
        // 7.1 藏掉铺满整条 bar 的背景层
        BOOL hiddenAny = NO;
        for (UIView *child in [bar.subviews copy]) {
            if (!child || child.isHidden) continue;
            NSUInteger kind = ZKKindOfView(child);
            if (kind != ZKViewKindBackground) continue;
            if (ZKContainsTabContent(child)) continue;          // 里面有 tab 内容，不能碰
            CGSize fz = child.frame.size;
            if (fz.height < barBounds.size.height - 1.0) continue;
            if (fz.width  < barBounds.size.width  - 1.0) continue;
            if (fz.height <= 1.0 || fz.width <= 1.0) continue;
            child.hidden = YES;
            child.alpha = 0;
            child.userInteractionEnabled = NO;
            hiddenAny = YES;
        }
        if (hiddenAny) ZKApplyTabBarTransparency(bar);

        // 7.2 找玻璃底板 + 全部 item
        UIView *platter = nil;
        NSMutableArray<UIView *> *items = [NSMutableArray array];
        for (UIView *child in bar.subviews) {
            NSUInteger kind = ZKKindOfView(child);
            if (kind == ZKViewKindPlatter) {
                if (!platter) platter = child;
            } else if (kind == ZKViewKindItem) {
                [items addObject:child];
            }
        }
        if (!platter || items.count == 0) return;

        CGRect platterFrame = platter.frame;
        if (CGRectIsEmpty(platterFrame) || CGRectIsNull(platterFrame)) return;
        if (platterFrame.size.width < 4.0 || platterFrame.size.height < 4.0) return;

        [items sortUsingComparator:^NSComparisonResult(id a, id b) {
            CGFloat ax = ((UIView *)a).frame.origin.x, bx = ((UIView *)b).frame.origin.x;
            if (ax < bx) return NSOrderedAscending;
            return ax > bx ? NSOrderedDescending : NSOrderedSame;
        }];

        NSUInteger count = items.count;
        if (count == 0) return;

        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        for (NSUInteger i = 0; i < count; i++) {
            UIView *item = items[i];
            CGPoint center = item.center;

            // item 内可见子视图的并集，用来做垂直居中
            CGRect unionRect = CGRectNull;
            for (UIView *sub in item.subviews) {
                if (sub.isHidden) continue;
                unionRect = CGRectUnion(unionRect, sub.frame);
            }

            CGFloat targetY = center.y;
            if (!CGRectIsEmpty(unionRect)) {
                CGFloat contentMidY = item.frame.origin.y + CGRectGetMidY(unionRect);
                targetY = center.y + (CGRectGetMidY(platterFrame) - contentMidY);
            }
            CGFloat targetX = platterFrame.origin.x
                            + ((CGFloat)i + 0.5) * platterFrame.size.width / (CGFloat)count;

            if (fabs(center.x - targetX) >= 0.5 || fabs(center.y - targetY) >= 0.5) {
                [item setCenter:CGPointMake(targetX, targetY)];
            }
        }
        [CATransaction commit];
    } @catch (NSException *e) {
        NSLog(@"[wctabbar] relayout failed: %@", e);
    } @finally {
        gZKInRelayout = NO;
    }
}

// 从 layoutSubviews 里只排一次，真正的改动留到下一轮主队列
static void ZKScheduleRelayout(UIView *bar) {
    if (!bar) return;
    if (objc_getAssociatedObject(bar, &kZKPendingKey)) return;
    objc_setAssociatedObject(bar, &kZKPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    __weak UIView *weakBar = bar;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *b = weakBar;
        if (!b) return;
        objc_setAssociatedObject(b, &kZKPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ZKRelayoutTabBarNow(b);
    });
}

// ----------------------------------------------------------------------------
// 8. 边缘效果视图
// ----------------------------------------------------------------------------

static BOOL ZKEdgeShouldBeHidden(id edgeView) {
    if (!edgeView) return NO;
    UIView *v = (UIView *)edgeView;

    UIWindow *window = [v window];
    if (!window) return NO;

    CGRect rectInWindow = [v convertRect:[v bounds] toView:window];
    if (!CGRectIsEmpty(rectInWindow)) {
        UIEdgeInsets inset = [window safeAreaInsets];
        CGFloat topLimit = inset.top + kZKTopBarHeight + kZKTopTolerance;
        if (CGRectGetMinY(rectInWindow) <= topLimit && CGRectGetMaxY(rectInWindow) > 1.0) return YES;
    }

    UIView *lastBar = gZKLastBar;
    if (!lastBar || [lastBar window] != window || [lastBar isHidden]) return NO;

    CGRect barRect  = [lastBar convertRect:[lastBar bounds] toView:window];
    CGRect edgeRect = [v convertRect:[v bounds] toView:window];
    CGRect overlap  = CGRectIntersection(barRect, edgeRect);
    if (CGRectIsNull(overlap)) return NO;

    return CGRectGetHeight(overlap) > 1.0 && CGRectGetWidth(overlap) > 1.0;
}

static void ZKRefreshEdgeView(UIView *edgeView) {
    if (!edgeView) return;
    NSNumber *requested = objc_getAssociatedObject(edgeView, kZKEdgeHiddenKey);
    BOOL want = [requested boolValue] ? YES : ZKEdgeShouldBeHidden(edgeView);
    if (want == edgeView.isHidden) return;

    gZKInSetHidden = YES;
    [edgeView setHidden:want];
    gZKInSetHidden = NO;
}

static void ZKRefreshAllEdgeViews(void) {
    for (UIView *edgeView in [ZKEdgeViewTable() allObjects]) {
        ZKRefreshEdgeView(edgeView);
    }
}

static void ZKTrackTabBar(UIView *bar) {
    if (!bar) return;
    if ([bar window]) { gZKLastBar = bar; return; }
    if (gZKLastBar == bar) { gZKLastBar = nil; return; }
    ZKRefreshAllEdgeViews();
}

// ----------------------------------------------------------------------------
// 9. 原函数指针
// ----------------------------------------------------------------------------

static void (*zkOrig_bar_setStandardAppearance)(id, SEL, id);
static void (*zkOrig_bar_setScrollEdgeAppearance)(id, SEL, id);
static void (*zkOrig_bar_setBackgroundImage)(id, SEL, UIImage *);
static void (*zkOrig_bar_setShadowImage)(id, SEL, UIImage *);
static void (*zkOrig_bar_setBarTintColor)(id, SEL, UIColor *);
static void (*zkOrig_bar_setBackgroundColor)(id, SEL, UIColor *);
static void (*zkOrig_bar_layoutSubviews)(id, SEL);
static void (*zkOrig_bar_didMoveToWindow)(id, SEL);
static void (*zkOrig_bar_setHidden)(id, SEL, BOOL);
static void (*zkOrig_bar_didMoveToSuperview)(id, SEL);
static void (*zkOrig_bar_traitCollectionDidChange)(id, SEL, id);
static void (*zkOrig_ctl_relayoutButtons)(id, SEL, void *);
static void (*zkOrig_edge_setHidden)(id, SEL, BOOL);
static void (*zkOrig_edge_layoutSubviews)(id, SEL);
static void (*zkOrig_edge_didMoveToWindow)(id, SEL);

// ----------------------------------------------------------------------------
// 10. hook 实现
// ----------------------------------------------------------------------------

static void zk_bar_noop(id self, SEL _cmd, id arg) { (void)self; (void)_cmd; (void)arg; }

static void zk_bar_setBackgroundColor(id self, SEL _cmd, UIColor *color) {
    if (color) {
        CGColorRef c = [color CGColor];
        if (c && CGColorGetAlpha(c) > kZKAlphaEpsilon) return;   // 有颜色就别设了
    }
    if (zkOrig_bar_setBackgroundColor) zkOrig_bar_setBackgroundColor(self, _cmd, color);
}

static void zk_bar_layoutSubviews(id self, SEL _cmd) {
    if (zkOrig_bar_layoutSubviews) zkOrig_bar_layoutSubviews(self, _cmd);
    @try {
        ZKScheduleRelayout((UIView *)self);
        ZKTrackTabBar((UIView *)self);
    } @catch (__unused NSException *e) {}
}

static void zk_bar_didMoveToWindow(id self, SEL _cmd) {
    if (zkOrig_bar_didMoveToWindow) zkOrig_bar_didMoveToWindow(self, _cmd);
    @try {
        ZKApplyTabBarTransparency(self);
        ZKTrackTabBar((UIView *)self);
        ZKScheduleRelayout((UIView *)self);
    } @catch (__unused NSException *e) {}
}

static void zk_bar_setHidden(id self, SEL _cmd, BOOL hidden) {
    if (zkOrig_bar_setHidden) zkOrig_bar_setHidden(self, _cmd, hidden);
    @try { ZKRefreshAllEdgeViews(); } @catch (__unused NSException *e) {}
}

static void zk_bar_didMoveToSuperview(id self, SEL _cmd) {
    if (zkOrig_bar_didMoveToSuperview) zkOrig_bar_didMoveToSuperview(self, _cmd);
    @try {
        ZKApplyTabBarTransparency(self);
        ZKTrackTabBar((UIView *)self);
    } @catch (__unused NSException *e) {}
}

static void zk_bar_traitCollectionDidChange(id self, SEL _cmd, id previous) {
    if (zkOrig_bar_traitCollectionDidChange) zkOrig_bar_traitCollectionDidChange(self, _cmd, previous);
    @try { ZKApplyTabBarTransparency(self); } @catch (__unused NSException *e) {}
}

static void zk_ctl_relayoutButtons(id self, SEL _cmd, void *arg) {
    if (zkOrig_ctl_relayoutButtons) zkOrig_ctl_relayoutButtons(self, _cmd, arg);

    UIView *bar = nil;
    @try {
        if ([self respondsToSelector:@selector(tabBar)]) {
            bar = (UIView *)[(MMTabBarController *)self tabBar];
        } else {
            id t = [self valueForKey:@"tabBar"];   // 老版本没有公开 getter，走 KVC
            if ([t isKindOfClass:[UIView class]]) bar = t;
        }
    } @catch (__unused NSException *e) {
        bar = nil;
    }
    if (!bar) return;

    ZKApplyTabBarTransparency(bar);
    ZKScheduleRelayout(bar);
}

static void zk_edge_setHidden(id self, SEL _cmd, BOOL hidden) {
    if (!gZKInSetHidden) {
        objc_setAssociatedObject(self, kZKEdgeHiddenKey, @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL value = hidden ? YES : ZKEdgeShouldBeHidden(self);
    if (zkOrig_edge_setHidden) zkOrig_edge_setHidden(self, _cmd, value);
}

static void zk_edge_layoutSubviews(id self, SEL _cmd) {
    if (zkOrig_edge_layoutSubviews) zkOrig_edge_layoutSubviews(self, _cmd);
    @try {
        [ZKEdgeViewTable() addObject:self];
        ZKRefreshEdgeView(self);
    } @catch (__unused NSException *e) {}
}

static void zk_edge_didMoveToWindow(id self, SEL _cmd) {
    if (zkOrig_edge_didMoveToWindow) zkOrig_edge_didMoveToWindow(self, _cmd);
    @try {
        [ZKEdgeViewTable() addObject:self];
        ZKRefreshEdgeView(self);
    } @catch (__unused NSException *e) {}
}

// ----------------------------------------------------------------------------
// 11. 安装
// ----------------------------------------------------------------------------

#define ZK_HOOK(cls, sel, repl, origp)                                  \
    do {                                                                \
        if ((cls) != Nil) {                                             \
            MSHookMessageEx((Class)(cls), @selector(sel),               \
                            (IMP)(repl), (IMP *)(origp));               \
        }                                                               \
    } while (0)

static BOOL sZKInstalled = NO;

void ZKInstallLiquidTabBar(void) {
    if (sZKInstalled) return;

    // 只在 iOS 26+ 上开，低版本没有 Liquid Glass
    if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion < 26) return;

    // 统一由设置页控制；和悬浮底栏互斥
    if (![LYHWConfig shared].liquidTabBarEnabled) return;
    if ([LYHWConfig shared].floatingTabBarEnabled) return;

    Class barClass = objc_getClass("MMTabBar");
    if (!barClass) {
        NSLog(@"[wctabbar] MMTabBar not found, liquid tabbar skipped");
        return;
    }
    sZKInstalled = YES;

    // 11.1 底栏本体
    ZK_HOOK(barClass, setStandardAppearance:,     zk_bar_noop, &zkOrig_bar_setStandardAppearance);
    ZK_HOOK(barClass, setScrollEdgeAppearance:,   zk_bar_noop, &zkOrig_bar_setScrollEdgeAppearance);
    ZK_HOOK(barClass, setBackgroundImage:,        zk_bar_noop, &zkOrig_bar_setBackgroundImage);
    ZK_HOOK(barClass, setShadowImage:,            zk_bar_noop, &zkOrig_bar_setShadowImage);
    ZK_HOOK(barClass, setBarTintColor:,           zk_bar_noop, &zkOrig_bar_setBarTintColor);
    ZK_HOOK(barClass, setBackgroundColor:,        zk_bar_setBackgroundColor, &zkOrig_bar_setBackgroundColor);
    ZK_HOOK(barClass, layoutSubviews,             zk_bar_layoutSubviews,    &zkOrig_bar_layoutSubviews);
    ZK_HOOK(barClass, didMoveToWindow,            zk_bar_didMoveToWindow,   &zkOrig_bar_didMoveToWindow);
    ZK_HOOK(barClass, setHidden:,                 zk_bar_setHidden,         &zkOrig_bar_setHidden);
    ZK_HOOK(barClass, didMoveToSuperview,         zk_bar_didMoveToSuperview,&zkOrig_bar_didMoveToSuperview);
    ZK_HOOK(barClass, traitCollectionDidChange:,  zk_bar_traitCollectionDidChange, &zkOrig_bar_traitCollectionDidChange);

    // 11.2 控制器：换 tab 时重排一遍
    ZK_HOOK(objc_getClass("MMTabBarController"), relayoutButtons:,
            zk_ctl_relayoutButtons, &zkOrig_ctl_relayoutButtons);

    // 11.3 滚动边缘效果视图
    Class edgeClass = NSClassFromString(kZKEdgeSwift);
    if (!edgeClass) edgeClass = objc_getClass([kZKEdgeMangled UTF8String]);
    if (!edgeClass) {
        NSLog(@"[wctabbar] ScrollEdgeEffectView not found, edge effect stays on");
        return;
    }
    ZK_HOOK(edgeClass, setHidden:,      zk_edge_setHidden,       &zkOrig_edge_setHidden);
    ZK_HOOK(edgeClass, layoutSubviews,  zk_edge_layoutSubviews,  &zkOrig_edge_layoutSubviews);
    ZK_HOOK(edgeClass, didMoveToWindow, zk_edge_didMoveToWindow, &zkOrig_edge_didMoveToWindow);

    NSLog(@"[wctabbar] liquid tabbar installed");
}

// ----------------------------------------------------------------------------
// 12. 独立编译本文件时的入口（工程里由 Tweak.x 调用，这里不生成）
// ----------------------------------------------------------------------------
#ifndef ZK_LIQUID_TABBAR_EXTERNAL_CTOR
%ctor {
    @autoreleasepool {
        ZKInstallLiquidCompatBypass();
        ZKInstallLiquidTabBar();
    }
}
#endif
