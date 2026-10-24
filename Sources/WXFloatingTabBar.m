// WXFloatingTabBar.m
// 悬浮底栏模块：hook 点、配置键与原版一一对应（纯 C + objc 运行时，便于交叉编译）
#include "WXFT.h"
#include <string.h>

extern id WXFTPrefColor(const char *key, double defWhite, double alpha);

static id strKey(const char *k){
    return ((id(*)(id,SEL,const char *))objc_msgSend)((id)CLS("NSString"), WS("stringWithUTF8String:"), k);
}
static BOOL clsHas(id o, const char *sub){
    const char *c = object_getClassName(o);
    return c && strstr(c, sub) != NULL;
}

static id   gBar = nil;
static id   gPanel = nil;
static id   gTarget = nil;
static double gLastHaptic = 0;
static BOOL gGesturesInstalled = NO;

#define kTagBackdrop 0x5758424BL
#define kTagPanel    0x5758504CL

#pragma mark - swizzle
static void hookSel(const char *cls, const char *sel, IMP imp, IMP *orig){
    Class c = CLS(cls); if(!c) return;
    void *m = class_getInstanceMethod(c, WS(sel)); if(!m) return;
    IMP old = method_setImplementation(m, imp);
    if(orig) *orig = old;
}

#pragma mark - 几何（公式取自原版反汇编）
typedef struct { double inset, height, y, radius, alpha, maskAlpha, scale; } WXFTGeo;

static WXFTGeo geoForBar(void){
    WXFTGeo g;
    double wPref  = WXFTPrefDouble("wkkFloatTabWidth",  -1.0);
    double yPref  = WXFTPrefDouble("wkkFloatTabY",      -4.0);
    double hPref  = WXFTPrefDouble("wkkFloatTabHeight", 12.0);
    double rPref  = WXFTPrefDouble("wkkFloatTabRadius", -1.0);
    double alpha  = WXFTPrefDouble("wkkFloatTabAlpha", 100.0) / 100.0;
    double mAlpha = WXFTPrefDouble("wkkFloatTabMaskAlpha", 100.0) / 100.0;
    double scale  = WXFTPrefDouble("wkkFloatTabButtonScale", 0.0);

    if(scale < 0) scale = 0;
    if(scale > 100) scale = 100;
    g.inset     = 30.0 - wPref;  if(g.inset < 0) g.inset = 0;
    g.height    = 58.0 + hPref;  if(g.height < 44) g.height = 44;
    g.y         = yPref;
    g.radius    = rPref;
    g.alpha     = (alpha <= 0 || alpha > 1) ? 1.0 : alpha;
    g.maskAlpha = (mAlpha <= 0 || mAlpha > 1) ? 1.0 : mAlpha;
    g.scale     = 1.0 + scale / 100.0;
    return g;
}

static CGRect targetFrame(id sv){
    CGRect sb = RECT0(sv, "bounds");
    WXFTGeo g = geoForBar();
    CGFloat gap = 12.0 - g.y; if(gap < 0) gap = 0;
    CGFloat h = g.height; if(h > sb.size.height) h = sb.size.height;
    CGFloat w = sb.size.width - 2*g.inset; if(w < 80) w = sb.size.width;
    return CGRectMake(g.inset, sb.size.height - h - gap, w, h);
}

#pragma mark - 背景
static void applyBackdrop(id bar, CGFloat radius, WXFTGeo g){
    id subviews = S0(bar, "subviews");
    unsigned long n = U0(subviews, "count"), i;
    id backdrop = nil;
    for(i=0;i<n;i++){
        id v = ((id(*)(id,SEL,unsigned long))objc_msgSend)(subviews, WS("objectAtIndex:"), i);
        if(L0(v, "tag") == kTagBackdrop){ backdrop = v; break; }
    }
    if(!backdrop && !WXFTPrefBool("wkkFloatTabNoMask", NO)){
        id eff = ((id(*)(id,SEL,long))objc_msgSend)((id)CLS("UIBlurEffect"), WS("effectWithStyle:"), 9L);
        backdrop = ((id(*)(id,SEL,id))objc_msgSend)((id)CLS("UIVisualEffectView"), WS("initWithEffect:"), eff);
        if(backdrop){
            V1L(backdrop, "setTag", kTagBackdrop);
            V1B(backdrop, "setUserInteractionEnabled", NO);
            ((void(*)(id,SEL,id,long))objc_msgSend)(bar, WS("insertSubview:atIndex:"), backdrop, 0L);
        }
    }
    if(backdrop){
        V1R(backdrop, "setFrame", RECT0(bar, "bounds"));
        V1D(S0(backdrop, "layer"), "setCornerRadius", radius);
        V1B(backdrop, "setClipsToBounds", YES);
        V1D(backdrop, "setAlpha", g.maskAlpha);
        V1(backdrop, "setBackgroundColor", WXFTPrefColor("wkkFloatTabBgLight", 1.0, 0.30));
    }
}

static void hideNativeBackground(id bar){
    id subviews = S0(bar, "subviews");
    unsigned long n = U0(subviews, "count"), i;
    for(i=0;i<n;i++){
        id v = ((id(*)(id,SEL,unsigned long))objc_msgSend)(subviews, WS("objectAtIndex:"), i);
        if(L0(v,"tag") == kTagBackdrop) continue;
        if(clsHas(v, "UIBarBackground") || clsHas(v, "UIImageView")) V1B(v, "setHidden", YES);
    }
}

#pragma mark - 子项
static int collectItems(id bar, __unsafe_unretained id *buf, int cap){
    id subviews = S0(bar, "subviews");
    unsigned long n = U0(subviews, "count"), i; int k = 0, j, m;
    for(i=0;i<n && k<cap;i++){
        id v = ((id(*)(id,SEL,unsigned long))objc_msgSend)(subviews, WS("objectAtIndex:"), i);
        if(L0(v,"tag") == kTagBackdrop) continue;
        if(clsHas(v, "TabBarItemView") || clsHas(v, "UITabBarButton")) buf[k++] = v;
    }
    for(j=0;j<k;j++) for(m=j+1;m<k;m++){
        CGRect a = RECT0(buf[j], "frame"), b = RECT0(buf[m], "frame");
        if(b.origin.x < a.origin.x){ id t = buf[j]; buf[j] = buf[m]; buf[m] = t; }
    }
    return k;
}

static void hideItemText(id item){
    id subviews = S0(item, "subviews");
    unsigned long n = U0(subviews, "count"), i;
    for(i=0;i<n;i++){
        id v = ((id(*)(id,SEL,unsigned long))objc_msgSend)(subviews, WS("objectAtIndex:"), i);
        if(clsHas(v, "Label")) V1B(v, "setHidden", YES);
    }
}

static void layoutItems(id bar, WXFTGeo g){
    __unsafe_unretained id items[16]; int n = collectItems(bar, items, 16), i;
    if(n <= 0) return;
    CGRect b = RECT0(bar, "bounds");
    CGFloat slot = b.size.width / (CGFloat)n;
    BOOL hideText = WXFTPrefBool("wkkFloatTabHideText", NO);
    for(i=0;i<n;i++){
        V1R(items[i], "setFrame", CGRectMake(slot*i, 0, slot, b.size.height));
        if(hideText) hideItemText(items[i]);
        if(g.scale != 1.0){
            V1R(items[i], "setBounds", CGRectMake(0, 0, slot*g.scale, b.size.height*g.scale));
            V1P(items[i], "setCenter", CGPointMake(slot*i + slot*0.5, b.size.height*0.5));
        }
    }
}

#pragma mark - 应用布局
void WXFTApplyFloatingLayout(id bar){
    if(!bar) return;
    gBar = bar;
    id sv = S0(bar, "superview"); if(!sv) return;
    WXFTGeo g = geoForBar();
    CGRect f = targetFrame(sv);
    V1R(bar, "setFrame", f);

    CGFloat radius = (g.radius < 0) ? WXFTMax(f.size.height*0.5 - 1.0, 0)
                                    : WXFTMax(WXFTMin(g.radius, f.size.height*0.5), 0);
    id layer = S0(bar, "layer");
    V1D(layer, "setCornerRadius", radius);
    V1D(layer, "setShadowOpacity", 0.18);
    V1D(layer, "setShadowRadius", 14.0);
    ((void(*)(id,SEL,CGSize))objc_msgSend)(layer, WS("setShadowOffset:"), CGSizeMake(0, 6));
    V1(bar, "setBackgroundColor", ((id(*)(id,SEL,double,double))objc_msgSend)(
        (id)CLS("UIColor"), WS("colorWithWhite:alpha:"), 0.0, 0.0));
    V1D(bar, "setAlpha", g.alpha);

    applyBackdrop(bar, radius, g);
    hideNativeBackground(bar);
    layoutItems(bar, g);
}

#pragma mark - 手势
static void ft_pan(id self, SEL _cmd, id gr){
    static CGRect startFrame;
    long state = L0(gr, "state");
    id sv = S0(self, "superview"); if(!sv) return;
    if(state == 1){
        startFrame = RECT0(self, "frame");
    } else if(state == 2){
        CGPoint t = ((CGPoint(*)(id,SEL,id))objc_msgSend)(gr, WS("translationInView:"), sv);
        CGRect f = startFrame;
        f.origin.x += t.x; f.origin.y += t.y;
        V1R(self, "setFrame", f);
    } else if(state == 3 || state == 4 || state == 5){
        CGRect sb = RECT0(sv, "bounds");
        CGRect f = RECT0(self, "frame");
        if(f.origin.y < 0) f.origin.y = 0;
        if(f.origin.y + f.size.height > sb.size.height) f.origin.y = sb.size.height - f.size.height;
        if(f.origin.x < 0) f.origin.x = 0;
        if(f.origin.x + f.size.width > sb.size.width) f.origin.x = sb.size.width - f.size.width;
        V1R(self, "setFrame", f);
        CGFloat gap = sb.size.height - (f.origin.y + f.size.height);
        WXFTPrefSetDouble("wkkFloatTabY", 12.0 - gap);
        WXFTPostSettingsChanged();
    }
    (void)_cmd;
}

static void ft_haptic(id self, SEL _cmd){
    id now = S0((id)CLS("NSDate"), "date");
    double t = now ? D0(now, "timeIntervalSince1970") : 0;
    if(t - gLastHaptic < 0.08) return;
    gLastHaptic = t;
    Class gc = CLS("UIImpactFeedbackGenerator");
    if(gc){
        id gen = S0((id)gc, "alloc");
        gen = ((id(*)(id,SEL,long))objc_msgSend)(gen, WS("initWithStyle:"), 1L);
        if(gen) V0(gen, "impactOccurred");
    }
    (void)self; (void)_cmd;
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

static void ftSliderChanged(id self, SEL _cmd, id s){
    long tag = L0(s, "tag");
    if(tag >= 0 && tag <= 5){
        WXFTPrefSetDouble(kSliderKeys[tag], (double)F0(s, "value"));
        if(gBar) WXFTApplyFloatingLayout(gBar);
    }
    (void)self; (void)_cmd;
}
static void ftSwitchChanged(id self, SEL _cmd, id s){
    long tag = L0(s, "tag");
    if(tag >= 100 && tag <= 104){
        WXFTPrefSetBool(kSwitchKeys[tag-100], B0(s, "isOn"));
        if(gBar) WXFTApplyFloatingLayout(gBar);
    }
    (void)self; (void)_cmd;
}

static id controlTarget(void){
    if(gTarget) return gTarget;
    Class c = objc_allocateClassPair(CLS("NSObject"), "WXFTControlTarget", 0);
    if(!c) return nil;
    class_addMethod(c, WS("ftSliderChanged:"), (IMP)ftSliderChanged, "v24@0:8@16");
    class_addMethod(c, WS("ftSwitchChanged:"), (IMP)ftSwitchChanged, "v24@0:8@16");
    objc_registerClassPair(c);
    gTarget = ((id(*)(id,SEL))objc_msgSend)((id)c, WS("new"));
    return gTarget;
}

static id quickPanel(void){
    if(gPanel) return gPanel;
    id tgt = controlTarget(); if(!tgt) return nil;
    id app = S0((id)CLS("UIApplication"), "sharedApplication");
    id key = app ? S0(app, "keyWindow") : nil;
    if(!key) return nil;

    id view = S0((id)CLS("UIView"), "alloc");
    view = ((id(*)(id,SEL))objc_msgSend)(view, WS("init"));
    if(!view) return nil;
    V1L(view, "setTag", kTagPanel);
    V1(view, "setBackgroundColor", WXFTPrefColor("wkkFloatTabBgDark", 0.08, 0.97));
    V1D(S0(view, "layer"), "setCornerRadius", 22.0);
    V1B(view, "setClipsToBounds", YES);

    id title = S0((id)CLS("UILabel"), "alloc");
    title = ((id(*)(id,SEL))objc_msgSend)(title, WS("init"));
    if(title){
        V1(title, "setText", strKey("悬浮底栏 · 快速设置"));
        V1(title, "setTextColor", ((id(*)(id,SEL,double,double))objc_msgSend)(
            (id)CLS("UIColor"), WS("colorWithWhite:alpha:"), 1.0, 1.0));
        V1(title, "setFont", ((id(*)(id,SEL,double))objc_msgSend)((id)CLS("UIFont"), WS("boldSystemFontOfSize:"), 17.0));
        V1R(title, "setFrame", CGRectMake(20, 18, 280, 24));
        V1(view, "addSubview:", title);
    }

    int i; double y = 56;
    for(i=0;i<6;i++){
        id lab = S0((id)CLS("UILabel"), "alloc");
        lab = ((id(*)(id,SEL))objc_msgSend)(lab, WS("init"));
        if(lab){
            V1(lab, "setText", strKey(kSliderKeys[i]));
            V1(lab, "setTextColor", ((id(*)(id,SEL,double,double))objc_msgSend)(
                (id)CLS("UIColor"), WS("colorWithWhite:alpha:"), 1.0, 0.75));
            V1(lab, "setFont", ((id(*)(id,SEL,double))objc_msgSend)((id)CLS("UIFont"), WS("systemFontOfSize:"), 12.0));
            V1R(lab, "setFrame", CGRectMake(20, y, 280, 16));
            V1(view, "addSubview:", lab);
        }
        id sl = S0((id)CLS("UISlider"), "alloc");
        sl = ((id(*)(id,SEL,CGRect))objc_msgSend)(sl, WS("initWithFrame:"), CGRectMake(20, y+18, 280, 26));
        if(sl){
            double mn = (i==4) ? 0 : ((i==0||i==3||i==2) ? -40 : 0);
            double mx = (i==4||i==5) ? 100 : ((i==1) ? 40 : ((i==2) ? 40 : 80));
            ((void(*)(id,SEL,float))objc_msgSend)(sl, WS("setMinimumValue:"), (float)mn);
            ((void(*)(id,SEL,float))objc_msgSend)(sl, WS("setMaximumValue:"), (float)mx);
            ((void(*)(id,SEL,float))objc_msgSend)(sl, WS("setValue:"),
                (float)WXFTPrefDouble(kSliderKeys[i],
                    (i==1)?12.0 : (i==2)?-4.0 : (i==4)?100.0 : (i==0||i==3)?-1.0 : 0.0));
            V1L(sl, "setTag", i);
            ((void(*)(id,SEL,id,SEL,unsigned long))objc_msgSend)(sl,
                WS("addTarget:action:forControlEvents:"), tgt, WS("ftSliderChanged:"), 4096UL);
            V1(view, "addSubview:", sl);
        }
        y += 52;
    }
    for(i=0;i<5;i++){
        id lab = S0((id)CLS("UILabel"), "alloc");
        lab = ((id(*)(id,SEL))objc_msgSend)(lab, WS("init"));
        if(lab){
            V1(lab, "setText", strKey(kSwitchKeys[i]));
            V1(lab, "setTextColor", ((id(*)(id,SEL,double,double))objc_msgSend)(
                (id)CLS("UIColor"), WS("colorWithWhite:alpha:"), 1.0, 0.9));
            V1(lab, "setFont", ((id(*)(id,SEL,double))objc_msgSend)((id)CLS("UIFont"), WS("systemFontOfSize:"), 13.0));
            V1R(lab, "setFrame", CGRectMake(20, y+6, 220, 20));
            V1(view, "addSubview:", lab);
        }
        id sw = S0((id)CLS("UISwitch"), "alloc");
        sw = ((id(*)(id,SEL,CGRect))objc_msgSend)(sw, WS("initWithFrame:"), CGRectMake(240, y, 51, 31));
        if(sw){
            V1L(sw, "setTag", 100+i);
            ((void(*)(id,SEL,BOOL))objc_msgSend)(sw, WS("setOn:"), WXFTPrefBool(kSwitchKeys[i], i==4));
            ((void(*)(id,SEL,id,SEL,unsigned long))objc_msgSend)(sw,
                WS("addTarget:action:forControlEvents:"), tgt, WS("ftSwitchChanged:"), 4096UL);
            V1(view, "addSubview:", sw);
        }
        y += 40;
    }
    gPanel = view;
    return view;
}

static void ft_longPress(id self, SEL _cmd, id gr){
    (void)self; (void)_cmd;
    if(L0(gr, "state") != 1) return;
    if(!WXFTPrefBool("wkkFloatTabLongPopup", YES)) return;
    id view = quickPanel(); if(!view) return;
    id app = S0((id)CLS("UIApplication"), "sharedApplication");
    id key = app ? S0(app, "keyWindow") : nil;
    if(!key) return;
    V1(key, "addSubview:", view);
    V1R(view, "setFrame", CGRectMake(0, 0, 320, 430));
    CGRect wb = RECT0(key, "bounds");
    V1P(view, "setCenter", CGPointMake(wb.size.width*0.5, wb.size.height*0.5));
}

#pragma mark - 被 hook 的原实现
static IMP o_layoutSubviews = NULL, o_hitTest = NULL;
static IMP o_setBGColor = NULL, o_setBGImage = NULL, o_setShadowImage = NULL;
static IMP o_setBarTint = NULL, o_setStdAppearance = NULL, o_setScrollEdge = NULL;
static IMP o_selectIndex = NULL;
static IMP o_itemLayoutIcon = NULL, o_itemLayoutSubviews = NULL;
static IMP o_badgeSetFrame = NULL, o_badgeSetString = NULL;
static IMP o_touchesBegan = NULL, o_viewDidAppear = NULL, o_shouldInteractivePop = NULL;

static void ft_layoutSubviews(id self, SEL _cmd){
    if(o_layoutSubviews) ((void(*)(id,SEL))o_layoutSubviews)(self, _cmd);
    if(!WXFTIsEnabled()) return;
    Class c = object_getClass(self);
    if(!class_getInstanceMethod(c, WS("custom_handlePanGesture:")))
        class_addMethod(c, WS("custom_handlePanGesture:"), (IMP)ft_pan, "v24@0:8@16");
    if(!class_getInstanceMethod(c, WS("custom_handleQuickSettingsLongPress:")))
        class_addMethod(c, WS("custom_handleQuickSettingsLongPress:"), (IMP)ft_longPress, "v24@0:8@16");
    if(!class_getInstanceMethod(c, WS("custom_triggerHaptic")))
        class_addMethod(c, WS("custom_triggerHaptic"), (IMP)ft_haptic, "v16@0:8");

    if(!gGesturesInstalled){
        id pan = S0((id)CLS("UIPanGestureRecognizer"), "alloc");
        pan = ((id(*)(id,SEL,id,SEL))objc_msgSend)(pan, WS("initWithTarget:action:"), self, WS("custom_handlePanGesture:"));
        if(pan) V1(self, "addGestureRecognizer:", pan);
        id lp = S0((id)CLS("UILongPressGestureRecognizer"), "alloc");
        lp = ((id(*)(id,SEL,id,SEL))objc_msgSend)(lp, WS("initWithTarget:action:"), self, WS("custom_handleQuickSettingsLongPress:"));
        if(lp){
            ((void(*)(id,SEL,double))objc_msgSend)(lp, WS("setMinimumPressDuration:"), 0.45);
            V1(self, "addGestureRecognizer:", lp);
        }
        gGesturesInstalled = YES;
    }
    WXFTApplyFloatingLayout(self);
}

static id ft_hitTest(id self, SEL _cmd, CGPoint p, id ev){
    if(WXFTIsEnabled()){
        CGRect b = RECT0(self, "bounds");
        if(!CGRectContainsPoint(b, p)) return nil;
    }
    return o_hitTest ? ((id(*)(id,SEL,CGPoint,id))o_hitTest)(self, _cmd, p, ev) : nil;
}

static void ft_noop_setBGColor(id s, SEL c, id v){ if(!WXFTIsEnabled() && o_setBGColor) ((void(*)(id,SEL,id))o_setBGColor)(s,c,v); }
static void ft_noop_setBGImage(id s, SEL c, id v){ if(!WXFTIsEnabled() && o_setBGImage) ((void(*)(id,SEL,id))o_setBGImage)(s,c,v); }
static void ft_noop_setShadowImage(id s, SEL c, id v){ if(!WXFTIsEnabled() && o_setShadowImage) ((void(*)(id,SEL,id))o_setShadowImage)(s,c,v); }
static void ft_noop_setBarTint(id s, SEL c, id v){ if(!WXFTIsEnabled() && o_setBarTint) ((void(*)(id,SEL,id))o_setBarTint)(s,c,v); }
static void ft_noop_setStdAppearance(id s, SEL c, id v){ if(!WXFTIsEnabled() && o_setStdAppearance) ((void(*)(id,SEL,id))o_setStdAppearance)(s,c,v); }
static void ft_noop_setScrollEdge(id s, SEL c, id v){ if(!WXFTIsEnabled() && o_setScrollEdge) ((void(*)(id,SEL,id))o_setScrollEdge)(s,c,v); }

static void ft_selectIndex(id self, SEL _cmd, long idx){
    if(o_selectIndex) ((void(*)(id,SEL,long))o_selectIndex)(self, _cmd, idx);
    if(!WXFTIsEnabled()) return;
    if(!WXFTPrefBool("wkkFloatTabIconAnim", YES)) return;
    __unsafe_unretained id items[16]; int n = collectItems(self, items, 16), i;
    for(i=0;i<n;i++){
        if(i != (int)idx) continue;
        id anim = ((id(*)(id,SEL,id))objc_msgSend)((id)CLS("CAKeyframeAnimation"),
                    WS("animationWithKeyPath:"), strKey("transform.translation.y"));
        if(!anim) continue;
        id vals = S0((id)CLS("NSMutableArray"), "array");
        if(!vals) continue;
        double seq[5]; int k;
        seq[0]=0; seq[1]=-6; seq[2]=0; seq[3]=-3; seq[4]=0;
        for(k=0;k<5;k++){
            id num = ((id(*)(id,SEL,double))objc_msgSend)((id)CLS("NSNumber"), WS("numberWithDouble:"), seq[k]);
            V1(vals, "addObject:", num);
        }
        V1(anim, "setValues:", vals);
        ((void(*)(id,SEL,double))objc_msgSend)(anim, WS("setDuration:"), 0.32);
        ((void(*)(id,SEL,id))objc_msgSend)(anim, WS("setTimingFunction:"),
            ((id(*)(id,SEL,id))objc_msgSend)((id)CLS("CAMediaTimingFunction"),
             WS("functionWithName:"), strKey("easeInEaseOut")));
        ((void(*)(id,SEL,id,id))objc_msgSend)(S0(items[i], "layer"),
            WS("addAnimation:forKey:"), anim, strKey("jumpAnimation"));
    }
}

static void ft_itemLayoutIcon(id self, SEL _cmd){
    if(o_itemLayoutIcon) ((void(*)(id,SEL))o_itemLayoutIcon)(self, _cmd);
    if(WXFTIsEnabled() && WXFTPrefBool("wkkFloatTabHideText", NO)) hideItemText(self);
}

static void ft_itemLayoutSubviews(id self, SEL _cmd){
    if(o_itemLayoutSubviews) ((void(*)(id,SEL))o_itemLayoutSubviews)(self, _cmd);
    if(WXFTIsEnabled() && WXFTPrefBool("wkkFloatTabHideText", NO)) hideItemText(self);
}

static void ft_badgeSetFrame(id self, SEL _cmd, CGRect f){
    if(WXFTIsEnabled() && WXFTPrefBool("wkkFloatTabHideBadge", NO)){ V1B(self, "setHidden", YES); return; }
    if(o_badgeSetFrame) ((void(*)(id,SEL,CGRect))o_badgeSetFrame)(self, _cmd, f);
}

static void ft_badgeSetString(id self, SEL _cmd, id s){
    if(WXFTIsEnabled() && WXFTPrefBool("wkkFloatTabHideBadge", NO)){ V1B(self, "setHidden", YES); return; }
    if(o_badgeSetString) ((void(*)(id,SEL,id))o_badgeSetString)(self, _cmd, s);
}

static void ft_touchesBegan(id self, SEL _cmd, id touches, id ev){
    if(o_touchesBegan) ((void(*)(id,SEL,id,id))o_touchesBegan)(self, _cmd, touches, ev);
    if(!WXFTIsEnabled()) return;
    id sv = S0(self, "superview");
    if(sv && clsHas(sv, "MMTabBar")) ft_haptic(self, WS("custom_triggerHaptic"));
}

static void ft_viewDidAppear(id self, SEL _cmd, BOOL a){
    if(o_viewDidAppear) ((void(*)(id,SEL,BOOL))o_viewDidAppear)(self, _cmd, a);
    if(!WXFTIsEnabled() || !gBar) return;
    V1B(gBar, "setHidden", NO);
    WXFTApplyFloatingLayout(gBar);
}

static BOOL ft_shouldInteractivePop(id self, SEL _cmd){
    if(WXFTIsEnabled()) return YES;
    return o_shouldInteractivePop ? ((BOOL(*)(id,SEL))o_shouldInteractivePop)(self, _cmd) : NO;
}

#pragma mark - 安装
void WXFTInstall(void){
    static BOOL done = NO;
    if(done) return;
    done = YES;

    hookSel("MMTabBar", "layoutSubviews", (IMP)ft_layoutSubviews, &o_layoutSubviews);
    hookSel("MMTabBar", "hitTest:withEvent:", (IMP)ft_hitTest, &o_hitTest);
    hookSel("MMTabBar", "setBackgroundColor:", (IMP)ft_noop_setBGColor, &o_setBGColor);
    hookSel("MMTabBar", "setBackgroundImage:", (IMP)ft_noop_setBGImage, &o_setBGImage);
    hookSel("MMTabBar", "setShadowImage:", (IMP)ft_noop_setShadowImage, &o_setShadowImage);
    hookSel("MMTabBar", "setBarTintColor:", (IMP)ft_noop_setBarTint, &o_setBarTint);
    hookSel("MMTabBar", "setStandardAppearance:", (IMP)ft_noop_setStdAppearance, &o_setStdAppearance);
    hookSel("MMTabBar", "setScrollEdgeAppearance:", (IMP)ft_noop_setScrollEdge, &o_setScrollEdge);
    hookSel("MMTabBar", "selectIndex:", (IMP)ft_selectIndex, &o_selectIndex);

    hookSel("MMTabBarItemView", "layoutIcon", (IMP)ft_itemLayoutIcon, &o_itemLayoutIcon);
    hookSel("MMTabBarItemView", "layoutSubviews", (IMP)ft_itemLayoutSubviews, &o_itemLayoutSubviews);
    hookSel("MMBadgeView", "setFrame:", (IMP)ft_badgeSetFrame, &o_badgeSetFrame);
    hookSel("MMBadgeView", "setString:", (IMP)ft_badgeSetString, &o_badgeSetString);

    hookSel("UITabBarButton", "touchesBegan:withEvent:", (IMP)ft_touchesBegan, &o_touchesBegan);
    hookSel("MMUINavigationController", "viewDidAppear:", (IMP)ft_viewDidAppear, &o_viewDidAppear);
    hookSel("MainFrameAggregationViewController", "shouldInteractivePop", (IMP)ft_shouldInteractivePop, &o_shouldInteractivePop);
}

void WXInitFloatingTabBar(void){ WXFTInstall(); }
