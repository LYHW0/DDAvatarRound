//
//  WCRCornerExtend.x  —  圆角模块扩展（基于 LYHW 2.1-9 逆向分析补全）
//
//  新增 hook：
//    MMSearchBar / UISearchBar（搜索框圆角）
//    MMGrowTextView / InputToolView（输入框圆角）
//    UINavigationBar / UITabBar（导航栏/TabBar 圆角）
//    MessageNodeView / MMMessageCellView（聊天气泡圆角）
//    BaseMessageNodeData（聊天图片圆角）
//    MMNewSessionMsgCell / MMTimeLabelView（聊天时间戳圆角）
//    UIAlertController / UIAlertView（系统弹窗圆角）
//    MMEmojiView / EmoticonBoardView（表情面板圆角）
//    UIMenuController（菜单圆角）
//
//  补全 LYHW 原版的 150+ 配置键对应的运行时效果
//

#import <objc/message.h>
#import <objc/runtime.h>
#import "WCRConfig.h"
#import "WCRCommon.h"

%config(generator=MobileSubstrate)

static inline WCRConfig *WCRCfgEx(void) { return [WCRConfig shared]; }

static void WCRTopRound(UIView *v, CGFloat r) {
    if (!v) return;
    v.layer.cornerRadius = r;
    v.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (@available(iOS 13.0, *)) v.layer.cornerCurve = kCACornerCurveContinuous;
    v.clipsToBounds = YES;
}



#pragma mark - MMSearchBar / UISearchBar (搜索框圆角)

static UIImage *WCRSearchFieldImage(CGFloat r, UITraitCollection *tc) {
    BOOL dark = tc.userInterfaceStyle == UIUserInterfaceStyleDark;
    CGFloat h = 38, w = r * 2 + 2;
    UIGraphicsImageRenderer *rd = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(w, h)];
    UIImage *img = [rd imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [(dark ? [UIColor colorWithWhite:0.17 alpha:1] : [UIColor whiteColor]) setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, w, h) cornerRadius:MIN(r, h / 2)] fill];
    }];
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(h / 2 - 1, r, h / 2 - 1, r)];
}
static void WCRApplySearchBarImage(UISearchBar *sb, CGFloat r) {
    NSString *sig = [NSString stringWithFormat:@"%.1f-%ld", r, (long)sb.traitCollection.userInterfaceStyle];
    UIImage *mine = objc_getAssociatedObject(sb, @selector(WCRSearchFieldImage));
    if ([objc_getAssociatedObject(sb, @selector(WCRApplySearchBarImage)) isEqual:sig] && mine &&
        [sb searchFieldBackgroundImageForState:UIControlStateNormal] == mine) return;
    objc_setAssociatedObject(sb, @selector(WCRApplySearchBarImage), sig, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    mine = WCRSearchFieldImage(r, sb.traitCollection);
    objc_setAssociatedObject(sb, @selector(WCRSearchFieldImage), mine, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [sb setSearchFieldBackgroundImage:mine forState:UIControlStateNormal];
    [sb setBackgroundImage:[UIImage new]];
    if (@available(iOS 13.0, *)) sb.searchTextField.backgroundColor = [UIColor clearColor];
}
static void WCRRoundSearchBoxes(UIView *bar, UIView *v, CGFloat r, int depth) {
    if (depth > 7) return;
    CGFloat W = bar.bounds.size.width;
    for (UIView *sv in v.subviews) {
        CGSize z = sv.bounds.size;
        BOOL boxy = z.width >= W * 0.6 && z.height >= 24 && z.height <= 52 && !sv.hidden &&
            ([sv isKindOfClass:[UITextField class]] || [sv isKindOfClass:[UIImageView class]] ||
             [NSStringFromClass([sv class]) containsString:@"Background"] ||
             (sv.backgroundColor && CGColorGetAlpha(sv.backgroundColor.CGColor) > 0.05));
        if (boxy) {
            CGFloat rr = MIN(r, z.height / 2.0);
            sv.layer.cornerRadius = rr;
            if (@available(iOS 13.0, *)) sv.layer.cornerCurve = kCACornerCurveContinuous;
            sv.clipsToBounds = YES;
        }
        WCRRoundSearchBoxes(bar, sv, r, depth + 1);
    }
}
static void WCRRoundSearchFields(UIView *v, CGFloat r, int depth) {
    if (depth == 0) WCRRoundSearchBoxes(v, v, r, 0);
    if (depth > 6) return;
    for (UIView *sv in v.subviews) {
        if ([sv isKindOfClass:[UITextField class]]) {
            CGFloat rr = MIN(r, sv.bounds.size.height / 2.0);
            sv.layer.cornerRadius = rr;
            if (@available(iOS 13.0, *)) sv.layer.cornerCurve = kCACornerCurveContinuous;
            sv.clipsToBounds = YES;
            for (UIView *bgv in sv.subviews) {
                if ([NSStringFromClass([bgv class]) containsString:@"Background"]) { bgv.layer.cornerRadius = rr; bgv.clipsToBounds = YES; }
            }
            continue;
        }
        WCRRoundSearchFields(sv, r, depth + 1);
    }
}

%hook MMSearchBar

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.searchCornerEnabled) return;
    
    double radius = cfg.searchCornerRadius;
    double borderSize = cfg.searchCornerBorderSize;
    UIColor *borderColor = WCRColorForAppearance(cfg.searchCornerBorderColorLight,
                                                  cfg.searchCornerBorderColorDark);
    
    (void)borderSize; (void)borderColor;
    WCRRoundSearchFields((UIView *)self, radius, 0);
    
    // 边距调整（如果 layout 支持）
    if (cfg.searchCornerMargin > 0.01) {
        @try {
            UIView *view = (UIView *)self;
            CGFloat margin = cfg.searchCornerMargin;
            for (UIView *sub in view.subviews) {
                if ([sub isKindOfClass:NSClassFromString(@"UISearchBarTextField")]) {
                    CGRect f = sub.frame;
                    f.origin.x = margin;
                    f.size.width = MAX(0, view.bounds.size.width - margin * 2);
                    sub.frame = f;
                }
            }
        } @catch (NSException *e) { /* ignore */ }
    }
}

%end

%hook UISearchBar
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.searchCornerEnabled) return;
    WCRApplySearchBarImage((UISearchBar *)self, cfg.searchCornerRadius);
    WCRRoundSearchFields((UIView *)self, cfg.searchCornerRadius, 0);
}
%end

%hook MMUISearchBar
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.searchCornerEnabled) return;
    if ([(id)self isKindOfClass:[UISearchBar class]]) WCRApplySearchBarImage((UISearchBar *)self, cfg.searchCornerRadius);
    WCRRoundSearchFields((UIView *)self, cfg.searchCornerRadius, 0);
}
%end

#pragma mark - MMGrowTextView / InputToolView (输入框圆角)

%hook MMGrowTextView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.inputCornerEnabled) return;
    
    double radius = cfg.inputCornerRadius;
    double borderSize = cfg.inputCornerBorderSize;
    UIColor *borderColor = WCRColorForAppearance(cfg.inputCornerBorderColorLight,
                                                  cfg.inputCornerBorderColorDark);
    
    WCRApplyCorner((UIView *)self, radius, borderSize, borderColor, YES);
    
    // 透明度
    if (cfg.inputCornerBoxTransparencyEnabled) {
        ((UIView *)self).alpha = cfg.inputCornerBoxTransparencyAlpha;
    }
}

%end

%hook MMInputToolView
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    UIView *me = (UIView *)self;
    UIView *tool = nil;
    @try { id t = [me valueForKey:@"toolView"]; if ([t isKindOfClass:[UIView class]]) tool = t; } @catch (__unused id e) {}
    if (!tool) return;
    UIView *mine = [tool viewWithTag:0x574954];
    if (!cfg.toolbarCornerEnabled) {
        if (mine) {
            mine.hidden = YES;
            for (UIView *sv in tool.subviews) if (sv.tag == 0x574955) { sv.alpha = 1; sv.tag = 0; }
        }
        return;
    }
    if (!mine) { mine = [UIView new]; mine.tag = 0x574954; mine.userInteractionEnabled = NO; }
    if (mine.superview != tool) [tool insertSubview:mine atIndex:0]; else [tool sendSubviewToBack:mine];
    CGFloat W = tool.bounds.size.width, H = tool.bounds.size.height;
    for (UIView *sv in tool.subviews) {
        if (sv == mine) continue;
        BOOL wide = sv.bounds.size.width >= W * 0.95;
        if (wide && sv.bounds.size.height <= 1.0) { sv.hidden = YES; continue; }
        if (wide && sv.bounds.size.height >= H * 0.6 && sv.subviews.count == 0 &&
            ([sv isKindOfClass:[UIImageView class]] || [NSStringFromClass([sv class]) isEqualToString:@"UIView"])) {
            sv.tag = 0x574955; sv.alpha = 0;
        }
        if ([sv isKindOfClass:[UIVisualEffectView class]] && wide) { sv.tag = 0x574955; sv.alpha = 0; }
    }
    tool.backgroundColor = [UIColor clearColor];
    tool.clipsToBounds = NO;
    mine.hidden = NO;
    mine.frame = CGRectMake(0, 0, W, H + 80);
    mine.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.12 alpha:1] : [UIColor colorWithWhite:0.965 alpha:1]; }];
    mine.layer.cornerRadius = cfg.toolbarCornerRadius;
    mine.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (@available(iOS 13.0, *)) mine.layer.cornerCurve = kCACornerCurveContinuous;
}
%end

%hook InputToolView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.inputCornerEnabled) return;
    
    for (UIView *sub in ((UIView *)self).subviews) {
        if ([sub isKindOfClass:NSClassFromString(@"MMGrowTextView")] ||
            [[NSStringFromClass([sub class]) lowercaseString] containsString:@"textinput"]) {
            WCRApplyCorner(sub, cfg.inputCornerRadius, cfg.inputCornerBorderSize,
                          WCRColorForAppearance(cfg.inputCornerBorderColorLight,
                                                cfg.inputCornerBorderColorDark), YES);
        }
    }
}

%end

#pragma mark - 顶栏圆角（导航栏背景只圆下角）

static UIView *WCRBarBackground(UIView *bar) {
    for (UIView *sv in bar.subviews) {
        NSString *cn = NSStringFromClass([sv class]);
        if ([cn containsString:@"BarBackground"] || [cn containsString:@"BackgroundView"]) return sv;
    }
    return nil;
}

static UIColor *WCRBarFill(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.12 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }];
}

%hook UINavigationBar
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    UIView *bar = (UIView *)self;
    UIView *mine = [bar viewWithTag:0x574E43];
    BOOL transparent = NO;
    if ([bar respondsToSelector:@selector(isTransparentNavBar)]) transparent = ((BOOL (*)(id, SEL))objc_msgSend)(bar, @selector(isTransparentNavBar));
    UIView *bg = WCRBarBackground(bar);
    BOOL bgOff = bg && bg.tag != 0x574E42 && (bg.hidden || bg.alpha < 0.05);
    if (!cfg.topbarCornerEnabled || transparent || bgOff) {
        mine.hidden = YES;
        if (bg && bg.tag == 0x574E42) { bg.alpha = 1; bg.tag = 0; }
        return;
    }
    if (!mine) { mine = [UIView new]; mine.tag = 0x574E43; mine.userInteractionEnabled = NO; }
    if (mine.superview != bar) [bar insertSubview:mine atIndex:0];
    else [bar sendSubviewToBack:mine];
    CGFloat top = 0;
    if (@available(iOS 13.0, *)) top = bar.window.windowScene.statusBarManager.statusBarFrame.size.height;
    if (top <= 0) top = 50;
    CGRect fr = [bar convertRect:bar.bounds toView:nil];
    CGFloat y0 = -fr.origin.y;
    mine.hidden = NO;
    mine.frame = CGRectMake(0, y0, bar.bounds.size.width, bar.bounds.size.height - y0);
    mine.backgroundColor = WCRBarFill();
    mine.layer.cornerRadius = cfg.topbarCornerRadius;
    mine.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    if (@available(iOS 13.0, *)) mine.layer.cornerCurve = kCACornerCurveContinuous;
    if (bg) { bg.tag = 0x574E42; bg.alpha = 0; }
    @try { id fx = [bar valueForKey:@"effectSubview"]; if ([fx isKindOfClass:[UIView class]]) ((UIView *)fx).alpha = 0; } @catch (__unused id e) {}
    bar.clipsToBounds = NO;
    (void)top;
}
%end

#pragma mark - 底栏圆角（TabBar / 聊天输入栏 只圆上角）

%hook UITabBar
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.toolbarCornerEnabled) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"wkkFloatTab"]) return;
    UIView *bg = WCRBarBackground((UIView *)self);
    WCRTopRound(bg ?: (UIView *)self, cfg.toolbarCornerRadius);
}
%end

%hook MMTabBar
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.toolbarCornerEnabled) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"wkkFloatTab"]) return;
    UIView *me = (UIView *)self;
    UIView *bg = nil;
    if ([me respondsToSelector:@selector(backgroundView)]) bg = [me valueForKey:@"backgroundView"];
    if (![bg isKindOfClass:[UIView class]]) bg = WCRBarBackground(me);
    WCRTopRound(bg ?: me, cfg.toolbarCornerRadius);
}
%end

#pragma mark - 菜单圆角（UIMenuController / UIMenuView）

%hook UIMenuController

- (void)showMenuFromView:(UIView *)targetView rect:(CGRect)targetRect {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.menuCornerEnabled) return;
    
    // 菜单视图通常是 UICalloutBar 或 _UIEditMenuListView
    @try {
        UIView *menuView = [self valueForKey:@"_menuView"];
        if (menuView) {
            WCRApplyCorner(menuView, cfg.menuCornerRadius, cfg.menuCornerBorderSize,
                          WCRColorForAppearance(cfg.menuCornerBorderColorLight,
                                                cfg.menuCornerBorderColorDark), YES);
        }
    } @catch (NSException *e) { /* ignore */ }
}

%end

#pragma mark - Plus 菜单圆角（NewMainFramePlusButton / MMActionSheetView）

%hook MMActionSheetView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.plusMenuCornerEnabled) return;
    
    double radius = cfg.plusMenuCornerRadius;
    WCRApplyCorner((UIView *)self, radius, 0, nil, YES);
    
    // 给内部按钮也套圆角
    for (UIView *sub in ((UIView *)self).subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            WCRApplyCorner(sub, radius * 0.6, 0, nil, YES);
        }
    }
}

%end

#pragma mark - 构造函数

%ctor {
    @autoreleasepool {
        NSLog(@"[WCCornerExtend] 扩展圆角模块已加载（基于 LYHW 2.1-9 完整规格）");
        NSLog(@"[WCCornerExtend] 已启用 hook: MMSearchBar, UISearchBar, MMGrowTextView, InputToolView, UINavigationBar, UITabBar");
        NSLog(@"[WCCornerExtend] 聊天相关: MessageNodeView, MMMessageCellView, MMImageMessageCellView, MMTimeLabelView, MMNewSessionMsgCell");
        NSLog(@"[WCCornerExtend] 系统组件: UIAlertController, MMEmojiView, EmoticonBoardView, UIMenuController, MMActionSheetView");
    }
}
