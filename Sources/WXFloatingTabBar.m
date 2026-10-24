// WXFloatingTabBar.m
// 悬浮底栏模块：hook 点、配置键与原版一一对应（纯 C + objc 运行时，便于交叉编译）
//
// 稳定性约定（改这个文件前先读三遍）
//   1. install 只装 hook：不读盘、不写盘、不碰视图树。
//   2. 所有几何/子视图操作一律 dispatch 到下一轮主队列执行，同一个 bar 只排一次；
//      绝不在 layoutSubviews 里直接改 frame / 增删子视图，否则 layout → 改 frame → layout 递归直接把进程炸掉。
//   3. 每个 hook 入口都做空值 / 类型 / 重入检查，异常一律 @try 吞掉并回退原实现。
#include "WXFT.h"
#include <string.h>

#pragma mark - 基础工具

static id ft_string(const char *k) {
    return ((id(*)(id, SEL, const char *))objc_msgSend)((id)CLS("NSString"),
                                                       WS("stringWithUTF8String:"), k ? k : "");
}

static BOOL ft_classHasName(id obj, const char *sub) {
    if (!obj || !sub) return NO;
    const char *name = object_getClassName(obj);
    return name && strstr(name, sub) != NULL;
}

static BOOL ft_inWindow(id view) {
    return view && S0(view, "window") != nil;
}

static BOOL ft_isTabItem(id v) {
    return ft_classHasName(v, "TabBarItemView") || ft_classHasName(v, "UITabBarButton");
}

#define kTagBackdrop 0x5758424BL
#define kTagPanel    0x5758504CL
#define kFTMaxItems  16

static char kFTPendingKey;    // 本轮 layout 已经排过一次
static char kFTGesturesKey;   // 手势已装
static char kFTPanStartKey;   // 拖动起点 frame

static id __weak gBar = nil;  // 最近一条底栏（弱引用，避免底栏销毁后还吊着）
static id        gPanel = nil;
static id        gTarget = nil;
static double    gLastHaptic = 0;
static BOOL      sFTApplying = NO;

// 原实现指针：必须在使用点之前声明（ft_apply 里要直接绕过自己的 setter hook 设透明底）
static IMP o_layoutSubviews = NULL, o_hitTest = NULL;
static IMP o_setBGColor = NULL, o_setBGImage = NULL, o_setShadowImage = NULL;
static IMP o_setBarTint = NULL, o_setStdAppearance = NULL, o_setScrollEdge = NULL;
static IMP o_selectIndex = NULL;
static IMP o_itemLayoutIcon = NULL, o_itemLayoutSubviews = NULL;
static IMP o_badgeSetFrame = NULL, o_badgeSetString = NULL;
static IMP o_touchesBegan = NULL, o_viewDidAppear = NULL, o_shouldInteractivePop = NULL;

#pragma mark - swizzle

static void hookSel(const char *cls, const char *sel, IMP imp, IMP *orig) {
    Class c = CLS(cls);
    if (!c) return;
    Method m = class_getInstanceMethod(c, WS(sel));
    if (!m) return;
    IMP old = method_setImplementation(m, imp);
    if (orig && old != imp) *orig = old;   // 绝不把替换后的实现当原实现存起来（会无限递归）
}

#pragma mark - 配置快照（一次 layout 只读一遍盘）

typedef struct { CGFloat inset, height, gap, radius, alpha, maskAlpha, scale; } WXFTGeo;
typedef struct {
    BOOL enabled, hideText, hideBadge, noMask, longPopup, iconAnim;
    WXFTGeo geo;
} WXFTConf;

static WXFTGeo ft_geo(void) {
    WXFTGeo g;
    double wPref = WXFTPrefDouble("wkkFloatTabWidth",  -1.0);
    double yPref = WXFTPrefDouble("wkkFloatTabY",      -4.0);
    double hPref = WXFTPrefDouble("wkkFloatTabHeight", 12.0);
    double rPref = WXFTPrefDouble("wkkFloatTabRadius", -1.0);
    double alpha = WXFTPrefDouble("wkkFloatTabAlpha", 100.0) / 100.0;
    double mAlpha = WXFTPrefDouble("wkkFloatTabMaskAlpha", 100.0) / 100.0;
    double scale = WXFTPrefDouble("wkkFloatTabButtonScale", 0.0);

    if (scale < 0) scale = 0;
    if (scale > 100) scale = 100;

    g.inset  = 30.0 - wPref;
    if (g.inset < 0) g.inset = 0;
    g.height = 58.0 + hPref;
    if (g.height < 44) g.height = 44;
    g.gap    = 12.0 - yPref;
    if (g.gap < 0) g.gap = 0;
    g.radius = rPref;
    g.alpha  = (alpha <= 0 || alpha > 1) ? 1.0 : alpha;
    g.maskAlpha = (mAlpha <= 0 || mAlpha > 1) ? 1.0 : mAlpha;
    g.scale  = 1.0 + scale / 100.0;
    return g;
}

static WXFTConf ft_conf(void) {
    WXFTConf c;
    memset(&c, 0, sizeof(c));
    c.enabled   = WXFTIsEnabled();
    c.geo       = ft_geo();
    c.hideText  = WXFTPrefBool("wkkFloatTabHideText", NO);
    c.hideBadge = WXFTPrefBool("wkkFloatTabHideBadge", NO);
    c.noMask    = WXFTPrefBool("wkkFloatTabNoMask", NO);
    c.longPopup = WXFTPrefBool("wkkFloatTabLongPopup", YES);
    c.iconAnim  = WXFTPrefBool("wkkFloatTabIconAnim", YES);
    return c;
}

static CGRect ft_target_frame(CGSize svSize, WXFTGeo g) {
    CGFloat width = svSize.width - 2 * g.inset;
    if (width < 80) width = svSize.width;                 // 留白调太大时退回整宽
    if (width < 1) width = 1;

    CGFloat height = g.height;
    if (height > svSize.height) height = svSize.height;   // 绝不让底栏高过父视图
    if (height < 1) height = 1;

    CGFloat y = svSize.height - height - g.gap;
    if (y < 0) y = 0;

    return CGRectMake(g.inset, y, width, height);
}

#pragma mark - 背景

static void ft_apply_backdrop(id bar, CGFloat radius, WXFTConf c) {
    id subviews = S0(bar, "subviews");
    if (!subviews) return;

    unsigned long n = U0(subviews, "count"), i;
    id backdrop = nil;
    for (i = 0; i < n; i++) {
        id v = ((id(*)(id, SEL, unsigned long))objc_msgSend)(subviews, WS("objectAtIndex:"), i);
        if (v && L0(v, "tag") == kTagBackdrop) { backdrop = v; break; }
    }

    if (!backdrop && !c.noMask) {
        id eff = ((id(*)(id, SEL, long))objc_msgSend)((id)CLS("UIBlurEffect"),
                                                      WS("effectWithStyle:"), 9L);
        if (eff) {
            backdrop = ((id(*)(id, SEL, id))objc_msgSend)((id)CLS("UIVisualEffectView"),
                                                          WS("initWithEffect:"), eff);
        }
        if (backdrop) {
            V1L(backdrop, "setTag", kTagBackdrop);
            V1B(backdrop, "setUserInteractionEnabled", NO);
            ((void(*)(id, SEL, id, long))objc_msgSend)(bar, WS("insertSubview:atIndex:"), backdrop, 0L);
        }
    }
    if (!backdrop) return;

    V1R(backdrop, "setFrame", RECT0(bar, "bounds"));
    id layer = S0(backdrop, "layer");
    if (layer) V1D(layer, "setCornerRadius", radius);
    V1B(backdrop, "setClipsToBounds", YES);
    V1D(backdrop, "setAlpha", c.geo.maskAlpha);
    V1(backdrop, "setBackgroundColor", WXFTPrefColor("wkkFloatTabBgLight", 1.0, 0.30));
}

// 只藏底栏自己的背景层，别碰 item
static void ft_hide_native_background(id bar) {
    id subviews = S0(bar, "subviews");
    if (!subviews) return;

    unsigned long n = U0(subviews, "count"), i;
    for (i = 0; i < n; i++) {
        id v = ((id(*)(id, SEL, unsigned long))objc_msgSend)(subviews, WS("objectAtIndex:"), i);
        if (!v || L0(v, "tag") == kTagBackdrop || ft_isTabItem(v)) continue;
        if (ft_classHasName(v, "Background")) { V1B(v, "setHidden", YES); continue; }
        if (B1(v, "isKindOfClass:", (id)CLS("UIImageView"))) V1B(v, "setHidden", YES);
    }
}

#pragma mark - 子项

static int ft_collect_items(id bar, __unsafe_unretained id *buf, int cap) {
    id subviews = S0(bar, "subviews");
    if (!subviews || !buf || cap <= 0) return 0;

    unsigned long n = U0(subviews, "count"), i;
    int k = 0, j, m;
    for (i = 0; i < n && k < cap; i++) {
        id v = ((id(*)(id, SEL, unsigned long))objc_msgSend)(subviews, WS("objectAtIndex:"), i);
        if (!v || L0(v, "tag") == kTagBackdrop) continue;
        if (ft_isTabItem(v)) buf[k++] = v;
    }
    for (j = 0; j < k; j++) {
        for (m = j + 1; m < k; m++) {
            CGRect a = RECT0(buf[j], "frame"), b = RECT0(buf[m], "frame");
            if (b.origin.x < a.origin.x) { id t = buf[j]; buf[j] = buf[m]; buf[m] = t; }
        }
    }
    return k;
}

static void ft_hide_item_text(id item) {
    id subviews = S0(item, "subviews");
    if (!subviews) return;
    unsigned long n = U0(subviews, "count"), i;
    for (i = 0; i < n; i++) {
        id v = ((id(*)(id, SEL, unsigned long))objc_msgSend)(subviews, WS("objectAtIndex:"), i);
        if (v && ft_classHasName(v, "Label")) V1B(v, "setHidden", YES);
    }
}

static void ft_layout_items(id bar, WXFTConf c) {
    __unsafe_unretained id items[kFTMaxItems];
    int n = ft_collect_items(bar, items, kFTMaxItems), i;
    if (n <= 0) return;

    CGRect b = RECT0(bar, "bounds");
    if (b.size.width < 1 || b.size.height < 1) return;

    CGFloat slot = b.size.width / (CGFloat)n;
    for (i = 0; i < n; i++) {
        CGRect want = CGRectMake(slot * i, 0, slot, b.size.height);
        if (!CGRectEqualToRect(RECT0(items[i], "frame"), want)) V1R(items[i], "setFrame", want);
        if (c.hideText) ft_hide_item_text(items[i]);
        if (c.geo.scale != 1.0) {
            V1R(items[i], "setBounds", CGRectMake(0, 0, slot * c.geo.scale, b.size.height * c.geo.scale));
            V1P(items[i], "setCenter", CGPointMake(slot * i + slot * 0.5, b.size.height * 0.5));
        }
    }
}

#pragma mark - 应用布局

static void ft_apply_inner(id bar) {
    id sv = S0(bar, "superview");
    if (!sv || !ft_inWindow(bar)) return;

    CGRect sb = RECT0(sv, "bounds");
    if (sb.size.width < 1 || sb.size.height < 1) return;

    WXFTConf c = ft_conf();
    CGRect f = ft_target_frame(sb.size, c.geo);

    if (!CGRectEqualToRect(RECT0(bar, "frame"), f)) V1R(bar, "setFrame", f);

    CGFloat radius = (c.geo.radius < 0) ? WXFTMax(f.size.height * 0.5 - 1.0, 0)
                                        : WXFTMax(WXFTMin(c.geo.radius, f.size.height * 0.5), 0);
    id layer = S0(bar, "layer");
    if (layer) {
        V1D(layer, "setCornerRadius", radius);
        V1D(layer, "setShadowOpacity", 0.18);
        V1D(layer, "setShadowRadius", 14.0);
        ((void(*)(id, SEL, CGSize))objc_msgSend)(layer, WS("setShadowOffset:"), CGSizeMake(0, 6));
    }

    // 注意：不能走自己的 hook（会被 ft_noop_setBGColor 吞掉），直接调原实现设成透明
    if (o_setBGColor) {
        ((void(*)(id, SEL, id))o_setBGColor)(bar, WS("setBackgroundColor:"),
                                             ((id(*)(id, SEL, double, double))objc_msgSend)(
                                                 (id)CLS("UIColor"), WS("colorWithWhite:alpha:"), 0.0, 0.0));
    }
    V1D(bar, "setAlpha", c.geo.alpha);

    ft_apply_backdrop(bar, radius, c);
    ft_hide_native_background(bar);
    ft_layout_items(bar, c);
}

static void ft_apply(id bar) {
    if (!bar || sFTApplying) return;
    if (!WXFTIsEnabled()) return;   // 关掉之后一个像素都不动
    sFTApplying = YES;
    @try {
        ft_apply_inner(bar);
    } @catch (NSException *e) {
        NSLog(@"[LYHW] floating tabbar apply failed: %@", e);
    }
    sFTApplying = NO;
}

// 从 layoutSubviews 里只排一次任务，真正的视图改动留到下一轮主队列
static void ft_schedule(id bar) {
    if (!bar) return;
    if (objc_getAssociatedObject(bar, &kFTPendingKey)) return;
    objc_setAssociatedObject(bar, &kFTPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    __weak id weakBar = bar;
    dispatch_async(dispatch_get_main_queue(), ^{
        id b = weakBar;
        if (!b) return;
        objc_setAssociatedObject(b, &kFTPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gBar = b;
        ft_apply(b);
    });
}

void WXFTApplyFloatingLayout(id bar) {
    if (!bar) return;
    gBar = bar;
    ft_apply(bar);
}

#pragma mark - 手势

static void ft_haptic(id self, SEL _cmd) {
    (void)self; (void)_cmd;
    id now = S0((id)CLS("NSDate"), "date");
    double t = now ? D0(now, "timeIntervalSince1970") : 0;
    if (t - gLastHaptic < 0.08) return;
    gLastHaptic = t;
    Class gc = CLS("UIImpactFeedbackGenerator");
    if (!gc) return;
    id gen = ((id(*)(id, SEL, long))objc_msgSend)(((id(*)(id, SEL))objc_msgSend)((id)gc, WS("alloc")),
                                                  WS("initWithStyle:"), 1L);
    if (gen) V0(gen, "impactOccurred");
}

static void ft_pan(id self, SEL _cmd, id gr) {
    (void)_cmd;
    if (!self || !gr) return;

    id sv = S0(self, "superview");
    if (!sv) return;

    long state = L0(gr, "state");
    if (state == 1) {                                    // began
        id v = ((id(*)(id, SEL, CGRect))objc_msgSend)((id)CLS("NSValue"),
                                                      WS("valueWithCGRect:"), RECT0(self, "frame"));
        objc_setAssociatedObject(self, &kFTPanStartKey, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    id startValue = objc_getAssociatedObject(self, &kFTPanStartKey);
    if (!startValue) return;

    if (state == 2) {                                    // changed
        CGPoint t = ((CGPoint(*)(id, SEL, id))objc_msgSend)(gr, WS("translationInView:"), sv);
        CGRect f = RECT0(startValue, "CGRectValue");
        f.origin.x += t.x;
        f.origin.y += t.y;
        V1R(self, "setFrame", f);
        return;
    }

    // ended / cancelled / failed：夹回父视图内，并把位置写进配置（这是用户主动操作，可以写盘）
    objc_setAssociatedObject(self, &kFTPanStartKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGRect sb = RECT0(sv, "bounds");
    CGRect f = RECT0(self, "frame");
    if (f.origin.y < 0) f.origin.y = 0;
    if (f.origin.y + f.size.height > sb.size.height) f.origin.y = sb.size.height - f.size.height;
    if (f.origin.x < 0) f.origin.x = 0;
    if (f.origin.x + f.size.width > sb.size.width) f.origin.x = sb.size.width - f.size.width;
    V1R(self, "setFrame", f);

    // 没真挪动就不写盘，避免每次点一下都落一次 preferences
    if (CGRectEqualToRect(RECT0(startValue, "CGRectValue"), f)) return;

    CGFloat gap = sb.size.height - (f.origin.y + f.size.height);
    WXFTPrefSetDouble("wkkFloatTabY", 12.0 - gap);
    WXFTPostSettingsChanged();
}

#pragma mark - 快速设置面板

static const char *kSliderKeys[] = {
    "wkkFloatTabWidth", "wkkFloatTabHeight", "wkkFloatTabY",
    "wkkFloatTabRadius", "wkkFloatTabAlpha", "wkkFloatTabButtonScale"
};
static const char *kSwitchKeys[] = {
    "wkkFloatTabHideText", "wkkFloatTabHideDot", "wkkFloatTabHideBadge",
    "wkkFloatTabNoMask", "wkkFloatTabLongPopup"
};

static void ft_slider_changed(id self, SEL _cmd, id s) {
    (void)self; (void)_cmd;
    if (!s) return;
    long tag = L0(s, "tag");
    if (tag < 0 || tag > 5) return;
    WXFTPrefSetDouble(kSliderKeys[tag], (double)F0(s, "value"));
    if (gBar) WXFTApplyFloatingLayout(gBar);
}

static void ft_switch_changed(id self, SEL _cmd, id s) {
    (void)self; (void)_cmd;
    if (!s) return;
    long tag = L0(s, "tag");
    if (tag < 100 || tag > 104) return;
    WXFTPrefSetBool(kSwitchKeys[tag - 100], B0(s, "isOn"));
    if (gBar) WXFTApplyFloatingLayout(gBar);
}

static void ft_close_panel(id self, SEL _cmd) {
    (void)self; (void)_cmd;
    if (gPanel) V0(gPanel, "removeFromSuperview");
    gPanel = nil;
}

static id ft_control_target(void) {
    if (gTarget) return gTarget;
    Class c = objc_allocateClassPair(CLS("NSObject"), "WXFTControlTarget", 0);
    if (!c) return nil;
    class_addMethod(c, WS("ftSliderChanged:"), (IMP)ft_slider_changed, "v24@0:8@16");
    class_addMethod(c, WS("ftSwitchChanged:"), (IMP)ft_switch_changed, "v24@0:8@16");
    class_addMethod(c, WS("ftClosePanel"), (IMP)ft_close_panel, "v16@0:8");
    objc_registerClassPair(c);
    gTarget = ((id(*)(id, SEL))objc_msgSend)((id)c, WS("new"));
    return gTarget;
}

static id ft_quick_panel(void) {
    if (gPanel) return gPanel;
    id tgt = ft_control_target();
    if (!tgt) return nil;

    id view = ((id(*)(id, SEL))objc_msgSend)(((id(*)(id, SEL))objc_msgSend)((id)CLS("UIView"), WS("alloc")), WS("init"));
    if (!view) return nil;
    V1L(view, "setTag", kTagPanel);
    V1(view, "setBackgroundColor", WXFTPrefColor("wkkFloatTabBgDark", 0.08, 0.97));
    id layer = S0(view, "layer");
    if (layer) V1D(layer, "setCornerRadius", 22.0);
    V1B(view, "setClipsToBounds", YES);

    id title = ((id(*)(id, SEL))objc_msgSend)(((id(*)(id, SEL))objc_msgSend)((id)CLS("UILabel"), WS("alloc")), WS("init"));
    if (title) {
        V1(title, "setText", ft_string("悬浮底栏 · 快速设置"));
        V1(title, "setTextColor", ((id(*)(id, SEL, double, double))objc_msgSend)(
            (id)CLS("UIColor"), WS("colorWithWhite:alpha:"), 1.0, 1.0));
        V1(title, "setFont", ((id(*)(id, SEL, double))objc_msgSend)(
            (id)CLS("UIFont"), WS("boldSystemFontOfSize:"), 17.0));
        V1R(title, "setFrame", CGRectMake(20, 16, 240, 24));
        V1(view, "addSubview:", title);
    }

    // 右上角关闭按钮，面板不再是"点不掉"的死窗口
    id close = ((id(*)(id, SEL, CGRect))objc_msgSend)(((id(*)(id, SEL))objc_msgSend)((id)CLS("UIButton"), WS("alloc")),
                                                     WS("initWithFrame:"), CGRectMake(278, 12, 32, 32));
    if (close) {
        V1(close, "setTitle", ft_string("✕"));
        V1(close, "setTitleColor", ((id(*)(id, SEL, double, double))objc_msgSend)(
            (id)CLS("UIColor"), WS("colorWithWhite:alpha:"), 1.0, 0.7));
        ((void(*)(id, SEL, id, SEL, unsigned long))objc_msgSend)(close,
            WS("addTarget:action:forControlEvents:"), tgt, WS("ftClosePanel"), 4096UL);
        V1(view, "addSubview:", close);
    }

    int i;
    double y = 50;
    for (i = 0; i < 6; i++) {
        id lab = ((id(*)(id, SEL))objc_msgSend)(((id(*)(id, SEL))objc_msgSend)((id)CLS("UILabel"), WS("alloc")), WS("init"));
        if (lab) {
            V1(lab, "setText", ft_string(kSliderKeys[i]));
            V1(lab, "setTextColor", ((id(*)(id, SEL, double, double))objc_msgSend)(
                (id)CLS("UIColor"), WS("colorWithWhite:alpha:"), 1.0, 0.75));
            V1(lab, "setFont", ((id(*)(id, SEL, double))objc_msgSend)(
                (id)CLS("UIFont"), WS("systemFontOfSize:"), 12.0));
            V1R(lab, "setFrame", CGRectMake(20, y, 280, 16));
            V1(view, "addSubview:", lab);
        }
        id sl = ((id(*)(id, SEL, CGRect))objc_msgSend)(((id(*)(id, SEL))objc_msgSend)((id)CLS("UISlider"), WS("alloc")),
                                                       WS("initWithFrame:"), CGRectMake(20, y + 18, 280, 26));
        if (sl) {
            double mn = (i == 4) ? 0 : ((i == 0 || i == 2 || i == 3) ? -40 : 0);
            double mx = (i == 4 || i == 5) ? 100 : ((i == 1 || i == 2) ? 40 : 80);
            ((void(*)(id, SEL, float))objc_msgSend)(sl, WS("setMinimumValue:"), (float)mn);
            ((void(*)(id, SEL, float))objc_msgSend)(sl, WS("setMaximumValue:"), (float)mx);
            ((void(*)(id, SEL, float))objc_msgSend)(sl, WS("setValue:"),
                (float)WXFTPrefDouble(kSliderKeys[i],
                    (i == 1) ? 12.0 : (i == 2) ? -4.0 : (i == 4) ? 100.0 : (i == 0 || i == 3) ? -1.0 : 0.0));
            V1L(sl, "setTag", i);
            ((void(*)(id, SEL, id, SEL, unsigned long))objc_msgSend)(sl,
                WS("addTarget:action:forControlEvents:"), tgt, WS("ftSliderChanged:"), 4096UL);
            V1(view, "addSubview:", sl);
        }
        y += 50;
    }
    for (i = 0; i < 5; i++) {
        id lab = ((id(*)(id, SEL))objc_msgSend)(((id(*)(id, SEL))objc_msgSend)((id)CLS("UILabel"), WS("alloc")), WS("init"));
        if (lab) {
            V1(lab, "setText", ft_string(kSwitchKeys[i]));
            V1(lab, "setTextColor", ((id(*)(id, SEL, double, double))objc_msgSend)(
                (id)CLS("UIColor"), WS("colorWithWhite:alpha:"), 1.0, 0.9));
            V1(lab, "setFont", ((id(*)(id, SEL, double))objc_msgSend)(
                (id)CLS("UIFont"), WS("systemFontOfSize:"), 13.0));
            V1R(lab, "setFrame", CGRectMake(20, y + 6, 220, 20));
            V1(view, "addSubview:", lab);
        }
        id sw = ((id(*)(id, SEL, CGRect))objc_msgSend)(((id(*)(id, SEL))objc_msgSend)((id)CLS("UISwitch"), WS("alloc")),
                                                       WS("initWithFrame:"), CGRectMake(240, y, 51, 31));
        if (sw) {
            V1L(sw, "setTag", 100 + i);
            ((void(*)(id, SEL, BOOL))objc_msgSend)(sw, WS("setOn:"), WXFTPrefBool(kSwitchKeys[i], i == 4));
            ((void(*)(id, SEL, id, SEL, unsigned long))objc_msgSend)(sw,
                WS("addTarget:action:forControlEvents:"), tgt, WS("ftSwitchChanged:"), 4096UL);
            V1(view, "addSubview:", sw);
        }
        y += 38;
    }

    V1R(view, "setFrame", CGRectMake(0, 0, 320, y + 10));
    gPanel = view;
    return view;
}

static void ft_long_press(id self, SEL _cmd, id gr) {
    (void)self; (void)_cmd;
    if (!gr || L0(gr, "state") != 1) return;
    if (!WXFTPrefBool("wkkFloatTabLongPopup", YES)) return;

    id view = ft_quick_panel();
    if (!view) return;

    id app = S0((id)CLS("UIApplication"), "sharedApplication");
    id key = app ? S0(app, "keyWindow") : nil;
    if (!key) return;

    if (S0(view, "superview") != key) V1(key, "addSubview:", view);
    CGRect wb = RECT0(key, "bounds");
    V1P(view, "setCenter", CGPointMake(wb.size.width * 0.5, wb.size.height * 0.5));
}

static void ft_install_gestures(id bar) {
    if (!bar) return;
    if (objc_getAssociatedObject(bar, &kFTGesturesKey)) return;

    Class c = object_getClass(bar);
    if (!c) return;

    if (!class_getInstanceMethod(c, WS("custom_handlePanGesture:")))
        class_addMethod(c, WS("custom_handlePanGesture:"), (IMP)ft_pan, "v24@0:8@16");
    if (!class_getInstanceMethod(c, WS("custom_handleQuickSettingsLongPress:")))
        class_addMethod(c, WS("custom_handleQuickSettingsLongPress:"), (IMP)ft_long_press, "v24@0:8@16");
    if (!class_getInstanceMethod(c, WS("custom_triggerHaptic")))
        class_addMethod(c, WS("custom_triggerHaptic"), (IMP)ft_haptic, "v16@0:8");

    BOOL added = NO;

    // 注意：alloc 之后直接 initWithTarget:action:，别先 init 再 initWith…（二次初始化会丢 target）
    id pan = ((id(*)(id, SEL))objc_msgSend)((id)CLS("UIPanGestureRecognizer"), WS("alloc"));
    if (pan) {
        pan = ((id(*)(id, SEL, id, SEL))objc_msgSend)(pan, WS("initWithTarget:action:"),
                                                      bar, WS("custom_handlePanGesture:"));
    }
    if (pan) {
        V1B(pan, "setCancelsTouchesInView", NO);   // 拖动底栏不要吃掉 tab 的点击
        V1(bar, "addGestureRecognizer:", pan);
        added = YES;
    }

    id lp = ((id(*)(id, SEL))objc_msgSend)((id)CLS("UILongPressGestureRecognizer"), WS("alloc"));
    if (lp) {
        lp = ((id(*)(id, SEL, id, SEL))objc_msgSend)(lp, WS("initWithTarget:action:"),
                                                     bar, WS("custom_handleQuickSettingsLongPress:"));
    }
    if (lp) {
        ((void(*)(id, SEL, double))objc_msgSend)(lp, WS("setMinimumPressDuration:"), 0.45);
        V1B(lp, "setCancelsTouchesInView", NO);
        V1(bar, "addGestureRecognizer:", lp);
        added = YES;
    }
    if (added) objc_setAssociatedObject(bar, &kFTGesturesKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 被 hook 的原实现

static void ft_layoutSubviews(id self, SEL _cmd) {
    if (o_layoutSubviews) ((void(*)(id, SEL))o_layoutSubviews)(self, _cmd);
    if (!WXFTIsEnabled()) return;

    @try {
        ft_install_gestures(self);
        ft_schedule(self);      // 视图改动全部延后，不在 layout 中途动
    } @catch (NSException *e) {
        NSLog(@"[LYHW] floating tabbar layout failed: %@", e);
    }
}

static id ft_hitTest(id self, SEL _cmd, CGPoint p, id ev) {
    if (WXFTIsEnabled() && self && !CGRectContainsPoint(RECT0(self, "bounds"), p)) return nil;
    return o_hitTest ? ((id(*)(id, SEL, CGPoint, id))o_hitTest)(self, _cmd, p, ev) : nil;
}

// 关掉悬浮底栏时，这些 setter 必须原样放行，否则微信自己的外观恢复不回来
static void ft_noop_setBGColor(id s, SEL c, id v)    { if (!WXFTIsEnabled() && o_setBGColor)    ((void(*)(id, SEL, id))o_setBGColor)(s, c, v); }
static void ft_noop_setBGImage(id s, SEL c, id v)    { if (!WXFTIsEnabled() && o_setBGImage)    ((void(*)(id, SEL, id))o_setBGImage)(s, c, v); }
static void ft_noop_setShadowImage(id s, SEL c, id v){ if (!WXFTIsEnabled() && o_setShadowImage) ((void(*)(id, SEL, id))o_setShadowImage)(s, c, v); }
static void ft_noop_setBarTint(id s, SEL c, id v)    { if (!WXFTIsEnabled() && o_setBarTint)     ((void(*)(id, SEL, id))o_setBarTint)(s, c, v); }
static void ft_noop_setStdAppearance(id s, SEL c, id v){ if (!WXFTIsEnabled() && o_setStdAppearance) ((void(*)(id, SEL, id))o_setStdAppearance)(s, c, v); }
static void ft_noop_setScrollEdge(id s, SEL c, id v){ if (!WXFTIsEnabled() && o_setScrollEdge)   ((void(*)(id, SEL, id))o_setScrollEdge)(s, c, v); }

static void ft_selectIndex(id self, SEL _cmd, long idx) {
    if (o_selectIndex) ((void(*)(id, SEL, long))o_selectIndex)(self, _cmd, idx);
    if (!WXFTIsEnabled() || !WXFTPrefBool("wkkFloatTabIconAnim", YES)) return;

    __unsafe_unretained id items[kFTMaxItems];
    int n = ft_collect_items(self, items, kFTMaxItems), i;
    if (idx < 0 || idx >= n) return;

    for (i = 0; i < n; i++) {
        if (i != (int)idx) continue;
        id anim = ((id(*)(id, SEL, id))objc_msgSend)((id)CLS("CAKeyframeAnimation"),
                                                     WS("animationWithKeyPath:"), ft_string("transform.translation.y"));
        if (!anim) return;
        id vals = S0((id)CLS("NSMutableArray"), "array");
        if (!vals) return;
        const double seq[5] = {0, -6, 0, -3, 0};
        int k;
        for (k = 0; k < 5; k++) {
            id num = ((id(*)(id, SEL, double))objc_msgSend)((id)CLS("NSNumber"), WS("numberWithDouble:"), seq[k]);
            if (num) V1(vals, "addObject:", num);
        }
        V1(anim, "setValues:", vals);
        ((void(*)(id, SEL, double))objc_msgSend)(anim, WS("setDuration:"), 0.32);
        ((void(*)(id, SEL, id))objc_msgSend)(anim, WS("setTimingFunction:"),
            ((id(*)(id, SEL, id))objc_msgSend)((id)CLS("CAMediaTimingFunction"),
                                               WS("functionWithName:"), ft_string("easeInEaseOut")));
        id layer = S0(items[i], "layer");
        if (layer) ((void(*)(id, SEL, id, id))objc_msgSend)(layer, WS("addAnimation:forKey:"),
                                                            anim, ft_string("jumpAnimation"));
    }
}

static void ft_itemLayoutIcon(id self, SEL _cmd) {
    if (o_itemLayoutIcon) ((void(*)(id, SEL))o_itemLayoutIcon)(self, _cmd);
    if (WXFTIsEnabled() && WXFTPrefBool("wkkFloatTabHideText", NO)) ft_hide_item_text(self);
}

static void ft_itemLayoutSubviews(id self, SEL _cmd) {
    if (o_itemLayoutSubviews) ((void(*)(id, SEL))o_itemLayoutSubviews)(self, _cmd);
    if (WXFTIsEnabled() && WXFTPrefBool("wkkFloatTabHideText", NO)) ft_hide_item_text(self);
}

static void ft_badgeSetFrame(id self, SEL _cmd, CGRect f) {
    if (WXFTIsEnabled() && WXFTPrefBool("wkkFloatTabHideBadge", NO)) { V1B(self, "setHidden", YES); return; }
    if (o_badgeSetFrame) ((void(*)(id, SEL, CGRect))o_badgeSetFrame)(self, _cmd, f);
}

static void ft_badgeSetString(id self, SEL _cmd, id s) {
    if (WXFTIsEnabled() && WXFTPrefBool("wkkFloatTabHideBadge", NO)) { V1B(self, "setHidden", YES); return; }
    if (o_badgeSetString) ((void(*)(id, SEL, id))o_badgeSetString)(self, _cmd, s);
}

static void ft_touchesBegan(id self, SEL _cmd, id touches, id ev) {
    if (o_touchesBegan) ((void(*)(id, SEL, id, id))o_touchesBegan)(self, _cmd, touches, ev);
    if (!WXFTIsEnabled()) return;
    if (ft_classHasName(S0(self, "superview"), "MMTabBar")) ft_haptic(self, WS("custom_triggerHaptic"));
}

static void ft_viewDidAppear(id self, SEL _cmd, BOOL a) {
    if (o_viewDidAppear) ((void(*)(id, SEL, BOOL))o_viewDidAppear)(self, _cmd, a);
    if (!WXFTIsEnabled()) return;
    id bar = gBar;
    if (bar) ft_schedule(bar);
}

static BOOL ft_shouldInteractivePop(id self, SEL _cmd) {
    if (WXFTIsEnabled()) return YES;   // 悬浮底栏不吃侧滑返回
    return o_shouldInteractivePop ? ((BOOL(*)(id, SEL))o_shouldInteractivePop)(self, _cmd) : NO;
}

#pragma mark - 安装

static BOOL sFTInstalled = NO;

BOOL WXFTIsInstalled(void) { return sFTInstalled; }

void WXFTInstall(void) {
    if (sFTInstalled) return;
    if (!CLS("MMTabBar")) {
        NSLog(@"[LYHW] MMTabBar not found, floating tabbar skipped");
        return;
    }
    sFTInstalled = YES;

    // 只装 hook，不动视图、不读盘、不写盘 —— 安装期任何多余动作都是启动闪退的来源
    hookSel("MMTabBar", "layoutSubviews",                 (IMP)ft_layoutSubviews,        &o_layoutSubviews);
    hookSel("MMTabBar", "hitTest:withEvent:",             (IMP)ft_hitTest,               &o_hitTest);
    hookSel("MMTabBar", "setBackgroundColor:",            (IMP)ft_noop_setBGColor,       &o_setBGColor);
    hookSel("MMTabBar", "setBackgroundImage:",            (IMP)ft_noop_setBGImage,       &o_setBGImage);
    hookSel("MMTabBar", "setShadowImage:",                (IMP)ft_noop_setShadowImage,   &o_setShadowImage);
    hookSel("MMTabBar", "setBarTintColor:",               (IMP)ft_noop_setBarTint,       &o_setBarTint);
    hookSel("MMTabBar", "setStandardAppearance:",         (IMP)ft_noop_setStdAppearance, &o_setStdAppearance);
    hookSel("MMTabBar", "setScrollEdgeAppearance:",       (IMP)ft_noop_setScrollEdge,    &o_setScrollEdge);
    hookSel("MMTabBar", "selectIndex:",                   (IMP)ft_selectIndex,           &o_selectIndex);

    hookSel("MMTabBarItemView", "layoutIcon",             (IMP)ft_itemLayoutIcon,        &o_itemLayoutIcon);
    hookSel("MMTabBarItemView", "layoutSubviews",         (IMP)ft_itemLayoutSubviews,    &o_itemLayoutSubviews);
    hookSel("MMBadgeView", "setFrame:",                   (IMP)ft_badgeSetFrame,         &o_badgeSetFrame);
    hookSel("MMBadgeView", "setString:",                  (IMP)ft_badgeSetString,        &o_badgeSetString);

    hookSel("UITabBarButton", "touchesBegan:withEvent:",  (IMP)ft_touchesBegan,          &o_touchesBegan);
    hookSel("MMUINavigationController", "viewDidAppear:", (IMP)ft_viewDidAppear,         &o_viewDidAppear);
    hookSel("MainFrameAggregationViewController", "shouldInteractivePop",
            (IMP)ft_shouldInteractivePop, &o_shouldInteractivePop);
}
