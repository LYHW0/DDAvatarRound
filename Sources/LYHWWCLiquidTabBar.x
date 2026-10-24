// ============================================================================
//  WCLiquidTabBar.xm
//  微信底栏「iOS 26 原生 Liquid Glass 浮动胶囊」还原实现
//  逆向自 com.x.wctabbar v1.0.1（作者 Riee）的 wctabbar.dylib（arm64, 70KB）
//  ---------------------------------------------------------------------------
//  适用：微信 iOS 8.0.5x+ / iOS 26（SystemVersion.majorVersion >= 26）
//  依赖：CydiaSubstrate / libsubstrate（MSHookMessageEx）
//  编译：Theos，ARC 打开，arm64
//  合并：把本文件丢进你的工程，加进 Makefile 的 FILES，或直接
//        #include "WCLiquidTabBar.xm"，然后在你的 %ctor 里调
//        ZKInstallLiquidTabBar()（定义 ZK_LIQUID_TABBAR_EXTERNAL_CTOR 可关掉本文件的 %ctor）
// ============================================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import <substrate.h>
#import "LYHWConfig.h"

#define ZK_LIQUID_TABBAR_EXTERNAL_CTOR 1

// ----------------------------------------------------------------------------
// 0. 常量 / 开关
// ----------------------------------------------------------------------------

// 总开关：NSUserDefaults key，缺省 = 开（有值且为 NO 时才关）
static NSString *const kZKPlistKey     = @"wclg_native_tabbar_enabled";

// Info.plist 里让 App 退回旧设计（非 Liquid Glass）的那把开关
static NSString *const kZKCompatKey    = @"UIDesignRequiresCompatibility";

// iOS 26 的滚动边缘效果视图（Swift 类，两种写法都试）
static NSString *const kZKEdgeSwift    = @"UIKit.ScrollEdgeEffectView";
static NSString *const kZKEdgeMangled  = @"_TtC5UIKit20ScrollEdgeEffectView";

// 子视图分类：靠类名子串识别，微信改类名时只需要改这里
static NSString *const kZKNamePlatter  = @"Platter";        // 玻璃胶囊底板
static NSString *const kZKNameItemView = @"MMTabBarItemView";// 每个 tab 的容器
static NSString *const kZKNameKind3[]  = {                  // 胶囊里可点的按钮/图标
    @"LiquidLens", @"TabBarButton", @"ItemView", @"Container", @"_UITabButton"
};

// 子视图种类
enum {
    ZKViewKindUnknown   = 0,   // 其它，不动
    ZKViewKindPlatter   = 1,   // 玻璃底板：定位基准
    ZKViewKindItem      = 2,   // tab item 容器：要重新均匀排布
    ZKViewKindButton    = 3,   // 按钮 / 图标 / 高光镜片
    ZKViewKindBackground= 4,   // 普通 UIView / UIVisualEffectView / 微信自己的视图：铺满就清掉
};

// 透明度阈值（原版就是 0.01，别改大，改大了微信的浅色背景会被一起吞掉）
static const CGFloat kZKAlphaEpsilon = 0.01;

// 顶部判定余量：safeAreaInsets.top + 44（导航栏）+ 1
static const CGFloat kZKTopBarHeight = 44.0;
static const CGFloat kZKTopTolerance = 1.0;

// ----------------------------------------------------------------------------
// 1. 全局状态
// ----------------------------------------------------------------------------

static os_unfair_lock      gZKPlistLock  = OS_UNFAIR_LOCK_INIT;  // 原版 0xc300
static NSDictionary       *gZKPlistSource;                       // 原版 0xc2f0（强引用上一次的原字典，objc_storeStrong）
static NSDictionary       *gZKPlistCache;                        // 原版 0xc2f8（改好的副本）

static NSMapTable         *gZKKindCache;                         // 原版 0xc308 类名 -> 种类 缓存
static dispatch_once_t     gZKKindOnce;                          // 原版 0xc310

static NSHashTable        *gZKEdgeViews;                         // 原版 0xc318 边缘效果视图弱表
static dispatch_once_t     gZKEdgeOnce;                          // 原版 0xc320

static BOOL                gZKInSetHidden = NO;                  // 原版 0xc328 防递归闸门

static UIView *__weak      gZKLastBar;                           // 原版 0xc260 最近一条底栏

// 关联对象 key（借用变量自身地址，保证全局唯一）
static const void *const kZKEdgeHiddenKey = &kZKEdgeHiddenKey;   // 原版 0xc258

// ----------------------------------------------------------------------------
// 1.5 微信侧的类（运行时才有，这里只声明类型，方便编译器认方法）
// ----------------------------------------------------------------------------
@interface MMTabBar : UITabBar @end
@interface MMTabBarController : UIViewController
@property (nonatomic, readonly, strong) UITabBar *tabBar;
@end

// ----------------------------------------------------------------------------
// 2. hook 原函数指针（原版 0xc268 ~ 0xc2e8）
// ----------------------------------------------------------------------------

static id            (*zkOrig_objectForInfoDictionaryKey)(id, SEL, NSString *);
static NSDictionary *(*zkOrig_infoDictionary)(id, SEL);

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

// 注意：原版这个参数在 hook 里原样透传，类型未知，用 void * 保证寄存器不被截断
static void (*zkOrig_ctl_relayoutButtons)(id, SEL, void *);

static void (*zkOrig_edge_setHidden)(id, SEL, BOOL);
static void (*zkOrig_edge_layoutSubviews)(id, SEL);
static void (*zkOrig_edge_didMoveToWindow)(id, SEL);

// ----------------------------------------------------------------------------
// 3. 小工具
// ----------------------------------------------------------------------------

// 原版 sub_490c：判断某个 "bundle 对象" 是不是主 bundle
// 只有主 bundle 的 Info.plist 才需要动，其它（插件、框架、图片包）一律放行
static BOOL ZKIsMainBundle(id bundle)
{
    return bundle == (id)[NSBundle mainBundle];
}

// 原版 sub_5bfc：懒建「类名 -> 种类」缓存表
static void ZKEnsureKindCache(void)
{
    dispatch_once(&gZKKindOnce, ^{
        gZKKindCache = [NSMapTable strongToStrongObjectsMapTable];
    });
}

// 原版 sub_5c10 / sub_57e4：懒建「边缘效果视图」弱表
static NSHashTable *ZKEdgeViewTable(void)
{
    dispatch_once(&gZKEdgeOnce, ^{
        gZKEdgeViews = [NSHashTable weakObjectsHashTable];
    });
    return gZKEdgeViews;
}

// ----------------------------------------------------------------------------
// 4. Info.plist 改造：把 UIDesignRequiresCompatibility 抹成 NO
//    （微信 iOS 26 版本会用它把自己锁在旧 UI，抹掉之后系统才给原生液态玻璃）
// ----------------------------------------------------------------------------

// 原版 0x4360
static id zk_objectForInfoDictionaryKey(id self, SEL _cmd, NSString *key)
{
    if ([key isEqualToString:kZKCompatKey] && ZKIsMainBundle(self)) {
        return (__bridge id)kCFBooleanFalse;
    }
    return zkOrig_objectForInfoDictionaryKey ? zkOrig_objectForInfoDictionaryKey(self, _cmd, key) : nil;
}

// 原版 0x4400
static NSDictionary *zk_infoDictionary(id self, SEL _cmd)
{
    NSDictionary *dict = zkOrig_infoDictionary ? zkOrig_infoDictionary(self, _cmd) : nil;
    if (dict[kZKCompatKey] == nil) return dict;
    if (!ZKIsMainBundle(self)) return dict;

    os_unfair_lock_lock(&gZKPlistLock);
    if (gZKPlistSource != dict) {
        NSMutableDictionary *mutableDict = [dict mutableCopy];
        if (mutableDict) {
            mutableDict[kZKCompatKey] = @NO;
            gZKPlistCache = [mutableDict copy];
            gZKPlistSource = dict;
        }
    }
    NSDictionary *result = gZKPlistCache ?: dict;
    os_unfair_lock_unlock(&gZKPlistLock);
    return result;
}

// ----------------------------------------------------------------------------
// 5. 子视图分类（原版 sub_5350）
//    带类名缓存，微信改类名时只需要改 kZKName* 常量
// ----------------------------------------------------------------------------

static NSUInteger ZKKindOfView(UIView *view)
{
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
        if (isButton) {
            kind = ZKViewKindButton;
        } else if (cls == [UIView class] ||
                   cls == [UIVisualEffectView class] ||
                   [NSBundle bundleForClass:cls] == [NSBundle mainBundle]) {
            // 系统 UIView / 毛玻璃底板 / 微信自己的视图 —— 都是「可能糊住胶囊的背景」
            kind = ZKViewKindBackground;
        } else {
            kind = ZKViewKindUnknown;
        }
    }

    [gZKKindCache setObject:@(kind) forKey:cls];
    return kind;
}

// ----------------------------------------------------------------------------
// 6. 把底栏本体做成全透明（原版 sub_50f8）
//    不透明、有底色、有 layer 底色 的时候才动手；已经是全透明就直接返回
// ----------------------------------------------------------------------------

static void ZKApplyTabBarTransparency(id object)
{
    if (!object) return;
    if (![object isKindOfClass:[UITabBar class]]) return;
    UITabBar *bar = (UITabBar *)object;

    BOOL hasVisibleBackground = NO;
    UIColor *bg = bar.backgroundColor;
    if (bg) {
        if (CGColorGetAlpha([bg CGColor]) > kZKAlphaEpsilon) hasVisibleBackground = YES;
    }
    if (!hasVisibleBackground) {
        CGColorRef layerColor = bar.layer.backgroundColor;
        if (layerColor) {
            if (CGColorGetAlpha(layerColor) > kZKAlphaEpsilon) hasVisibleBackground = YES;
        }
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
// 7. 去掉铺满整条 bar 的背景层 + 把 tab item 均匀摆进玻璃胶囊（原版 sub_496c）
// ----------------------------------------------------------------------------

static NSInteger ZKCompareByFrameX(id a, id b)
{
    CGFloat ax = ((UIView *)a).frame.origin.x;
    CGFloat bx = ((UIView *)b).frame.origin.x;
    if (ax < bx) return -1;
    return ax > bx ? 1 : 0;
}

static void ZKRelayoutTabBar(UIView *bar)
{
    if (!bar) return;

    // ---- 7.1 清掉盖满整条 bar 的旧背景（原生分割线 / 背板），否则会挡住液态玻璃
    BOOL removedAny = NO;
    NSArray<UIView *> *snapshot = [[bar subviews] copy];
    CGRect barBounds = bar.bounds;

    for (UIView *child in snapshot) {
        if (ZKKindOfView(child) != ZKViewKindBackground) continue;

        CGSize childSize = child.bounds.size;
        if (childSize.height < barBounds.size.height - 1.0) continue;
        if (childSize.width  < barBounds.size.width  - 1.0) continue;

        CGSize childFrame = child.frame.size;
        if (childFrame.height <= 1.0 || childFrame.width <= 1.0) continue;

        [child removeFromSuperview];
        removedAny = YES;
    }
    if (removedAny) ZKApplyTabBarTransparency(bar);

    // ---- 7.2 找出玻璃底板（Platter）和全部 item，按 x 排序后等分
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    __block UIView *platter = nil;

    for (UIView *child in [bar subviews]) {
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

    [items sortUsingComparator:^NSInteger(id a, id b) {
        return ZKCompareByFrameX(a, b);
    }];

    NSUInteger count = items.count;
    if (count == 0) return;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    for (NSUInteger i = 0; i < count; i++) {
        UIView *item = items[i];

        CGPoint center = item.center;

        // 该 item 里所有可见子视图的并集，用来做垂直居中
        CGRect unionRect = CGRectNull;
        for (UIView *sub in [item subviews]) {
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
}

// ----------------------------------------------------------------------------
// 8. 边缘效果视图（UIKit.ScrollEdgeEffectView）——原版 0x5900 / 0x5814 / 0x56a0 / 0x4780
// ----------------------------------------------------------------------------

// 原版 sub_5900：这条边缘模糊到底该不该藏
static BOOL ZKEdgeShouldBeHidden(id edgeView)
{
    if (!edgeView) return NO;

    UIWindow *window = [edgeView window];
    if (!window) return NO;

    CGRect rectInWindow = [edgeView convertRect:[edgeView bounds] toView:window];
    if (!CGRectIsEmpty(rectInWindow)) {
        UIEdgeInsets inset = [window safeAreaInsets];
        CGFloat topLimit = inset.top + kZKTopBarHeight + kZKTopTolerance;
        if (CGRectGetMinY(rectInWindow) <= topLimit) {
            if (CGRectGetMaxY(rectInWindow) > 1.0) return YES;
        }
    }

    UIView *lastBar = gZKLastBar;
    if (!lastBar) return NO;
    if ([lastBar window] != window) return NO;
    if ([lastBar isHidden]) return NO;

    CGRect barRect  = [lastBar  convertRect:[lastBar  bounds] toView:window];
    CGRect edgeRect = [edgeView convertRect:[edgeView bounds] toView:window];
    CGRect overlap  = CGRectIntersection(barRect, edgeRect);
    if (CGRectIsNull(overlap)) return NO;

    return CGRectGetHeight(overlap) > 1.0 && CGRectGetWidth(overlap) > 1.0;
}

// 原版 sub_5814：重新算一次并同步到真实的 setHidden:
static void ZKRefreshEdgeView(UIView *edgeView)
{
    if (!edgeView) return;

    NSNumber *requested = objc_getAssociatedObject(edgeView, kZKEdgeHiddenKey);
    BOOL want = [requested boolValue] ? YES : ZKEdgeShouldBeHidden(edgeView);

    if (want != edgeView.isHidden) {
        gZKInSetHidden = YES;
        [edgeView setHidden:want];
        gZKInSetHidden = NO;
    }
}

// 原版 sub_56a0：把所有登记过的边缘效果视图刷一遍
static void ZKRefreshAllEdgeViews(void)
{
    NSArray *all = [ZKEdgeViewTable() allObjects];
    for (UIView *edgeView in all) {
        ZKRefreshEdgeView(edgeView);
    }
}

// 原版 sub_506c：记录 / 注销「最近一条可见底栏」，并顺带触发一次全量刷新
static void ZKTrackTabBar(UIView *bar)
{
    if (!bar) return;

    if ([bar window]) {
        gZKLastBar = bar;
        return;
    }

    if (gZKLastBar == bar) {
        gZKLastBar = nil;
        return;
    }
    ZKRefreshAllEdgeViews();
}

// 原版 0x4780
static void zk_edge_setHidden(id self, SEL _cmd, BOOL hidden)
{
    if (!gZKInSetHidden) {
        objc_setAssociatedObject(self, kZKEdgeHiddenKey, @(hidden),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL value = hidden ? YES : ZKEdgeShouldBeHidden(self);
    if (zkOrig_edge_setHidden) zkOrig_edge_setHidden(self, _cmd, value);
}

// 原版 0x484c
static void zk_edge_layoutSubviews(id self, SEL _cmd)
{
    if (zkOrig_edge_layoutSubviews) zkOrig_edge_layoutSubviews(self, _cmd);
    [ZKEdgeViewTable() addObject:self];
    ZKRefreshEdgeView(self);
}

// 原版 0x48ac
static void zk_edge_didMoveToWindow(id self, SEL _cmd)
{
    if (zkOrig_edge_didMoveToWindow) zkOrig_edge_didMoveToWindow(self, _cmd);
    [ZKEdgeViewTable() addObject:self];
    ZKRefreshEdgeView(self);
}

// ----------------------------------------------------------------------------
// 9. MMTabBar / MMTabBarController 的 hook
// ----------------------------------------------------------------------------

// 原版 0x4568 / 0x456c / 0x4570 / 0x4574 / 0x4578：五个空实现
// 微信自己会往 tabBar 上塞外观、背景图、阴影图、染色，全给它吞了，
// 不然系统那层液态玻璃会被盖住。
static void zk_bar_noop(id self, SEL _cmd, id arg) { (void)self; (void)_cmd; (void)arg; }

// 原版 0x457c：只放行「透明」的 backgroundColor
static void zk_bar_setBackgroundColor(id self, SEL _cmd, UIColor *color)
{
    if (color) {
        CGFloat alpha = CGColorGetAlpha([color CGColor]);
        if (alpha > kZKAlphaEpsilon) return;   // 有颜色就别设了
    }
    if (zkOrig_bar_setBackgroundColor) zkOrig_bar_setBackgroundColor(self, _cmd, color);
}

// 原版 0x4604
static void zk_bar_layoutSubviews(id self, SEL _cmd)
{
    if (zkOrig_bar_layoutSubviews) zkOrig_bar_layoutSubviews(self, _cmd);
    ZKRelayoutTabBar((UIView *)self);
    ZKTrackTabBar((UIView *)self);
}

// 原版 0x4638
static void zk_bar_didMoveToWindow(id self, SEL _cmd)
{
    if (zkOrig_bar_didMoveToWindow) zkOrig_bar_didMoveToWindow(self, _cmd);
    ZKApplyTabBarTransparency(self);
    ZKTrackTabBar((UIView *)self);
}

// 原版 0x466c
static void zk_bar_setHidden(id self, SEL _cmd, BOOL hidden)
{
    if (zkOrig_bar_setHidden) zkOrig_bar_setHidden(self, _cmd, hidden);
    ZKRefreshAllEdgeViews();
}

// 原版 0x4688
static void zk_bar_didMoveToSuperview(id self, SEL _cmd)
{
    if (zkOrig_bar_didMoveToSuperview) zkOrig_bar_didMoveToSuperview(self, _cmd);
    ZKApplyTabBarTransparency(self);
    ZKTrackTabBar((UIView *)self);
}

// 原版 0x46b4
static void zk_bar_traitCollectionDidChange(id self, SEL _cmd, id previous)
{
    if (zkOrig_bar_traitCollectionDidChange) zkOrig_bar_traitCollectionDidChange(self, _cmd, previous);
    ZKApplyTabBarTransparency(self);
}

// 原版 0x4720
static void zk_ctl_relayoutButtons(id self, SEL _cmd, void *arg)
{
    if (zkOrig_ctl_relayoutButtons) zkOrig_ctl_relayoutButtons(self, _cmd, arg);

    UIView *bar = (UIView *)[(MMTabBarController *)self tabBar];
    if (!bar) return;
    ZKApplyTabBarTransparency(bar);
    ZKRelayoutTabBar(bar);
}

// ----------------------------------------------------------------------------
// 10. 安装（原版 0x4000）
// ----------------------------------------------------------------------------

#define ZK_HOOK(cls, sel, repl, origp)                                  \
    do {                                                                \
        if ((cls) != Nil) {                                             \
            MSHookMessageEx((Class)(cls), @selector(sel),               \
                            (IMP)(repl), (IMP *)(origp));               \
        }                                                               \
    } while (0)

void ZKInstallLiquidTabBar(void)
{
    // 只在 iOS 26+ 上开，低版本没有 Liquid Glass，挂了反而把底栏搞坏
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (version.majorVersion < 26) return;

    // 统一由兰因后悟设置页控制；默认关闭，避免与原底栏圆角逻辑冲突。
    if (![LYHWConfig shared].liquidTabBarEnabled) return;

    // 10.1 Info.plist：干掉「退回旧设计」的开关
    Class bundleClass = objc_getClass("NSBundle");
    ZK_HOOK(bundleClass, objectForInfoDictionaryKey:, zk_objectForInfoDictionaryKey,
            &zkOrig_objectForInfoDictionaryKey);
    ZK_HOOK(bundleClass, infoDictionary, zk_infoDictionary, &zkOrig_infoDictionary);

    // 10.2 底栏本体
    Class barClass = objc_getClass("MMTabBar");
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

    // 10.3 控制器：换 tab 时重新排一遍
    Class controllerClass = objc_getClass("MMTabBarController");
    ZK_HOOK(controllerClass, relayoutButtons:, zk_ctl_relayoutButtons, &zkOrig_ctl_relayoutButtons);

    // 10.4 iOS 26 的滚动边缘效果视图（Swift 类，先按 ObjC 名找，再按 mangled 名找）
    Class edgeClass = NSClassFromString(kZKEdgeSwift);
    if (!edgeClass) edgeClass = objc_getClass([kZKEdgeMangled UTF8String]);
    if (!edgeClass) {
        NSLog(@"[wctabbar] ScrollEdgeEffectView not found, edge effect stays on");
        return;
    }
    ZK_HOOK(edgeClass, setHidden:,       zk_edge_setHidden,       &zkOrig_edge_setHidden);
    ZK_HOOK(edgeClass, layoutSubviews,   zk_edge_layoutSubviews,  &zkOrig_edge_layoutSubviews);
    ZK_HOOK(edgeClass, didMoveToWindow,  zk_edge_didMoveToWindow, &zkOrig_edge_didMoveToWindow);
}

// ----------------------------------------------------------------------------
// 11. 入口
//    合并到别人的工程时定义 ZK_LIQUID_TABBAR_EXTERNAL_CTOR，然后在自己的
//    %ctor 里手动调 ZKInstallLiquidTabBar()
// ----------------------------------------------------------------------------
#ifndef ZK_LIQUID_TABBAR_EXTERNAL_CTOR
%ctor {
    @autoreleasepool {
        ZKInstallLiquidTabBar();
    }
}
#endif
