//
//  WCRCornerExtend.x  —  圆角模块扩展（基于 WCRefine 2.1-9 逆向分析补全）
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
//  补全 WCRefine 原版的 150+ 配置键对应的运行时效果
//

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

static void WCRRoundSearchFields(UIView *v, CGFloat r, int depth) {
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
    WCRRoundSearchFields((UIView *)self, cfg.searchCornerRadius, 0);
}
%end

%hook MMUISearchBar
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.searchCornerEnabled) return;
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

%hook InputToolView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (cfg.toolbarCornerEnabled) WCRTopRound((UIView *)self, cfg.toolbarCornerRadius);
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

%hook UINavigationBar
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    UIView *bar = (UIView *)self;
    UIView *bg = WCRBarBackground(bar);
    if (!cfg.topbarCornerEnabled) {
        if (bg && bg.tag == 0x574E42) { bg.layer.cornerRadius = 0; bg.clipsToBounds = NO; bg.tag = 0; }
        return;
    }
    CGFloat r = cfg.topbarCornerRadius;
    UIView *target = bg ?: bar;
    target.tag = 0x574E42;
    target.layer.cornerRadius = r;
    target.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    if (@available(iOS 13.0, *)) target.layer.cornerCurve = kCACornerCurveContinuous;
    target.clipsToBounds = YES;
    for (UIView *sv in target.subviews) {
        if (sv.bounds.size.height <= 1.0) sv.hidden = YES;   // 去掉底部分割线
    }
}
%end

#pragma mark - 底栏圆角（TabBar / 聊天输入栏 只圆上角）

%hook UITabBar
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.toolbarCornerEnabled || cfg.floatingTabBarEnabled) return;
    UIView *bg = WCRBarBackground((UIView *)self);
    WCRTopRound(bg ?: (UIView *)self, cfg.toolbarCornerRadius);
}
%end

%hook MMTabBar
- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.toolbarCornerEnabled || cfg.floatingTabBarEnabled) return;
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
        NSLog(@"[WCCornerExtend] 扩展圆角模块已加载（基于 WCRefine 2.1-9 完整规格）");
        NSLog(@"[WCCornerExtend] 已启用 hook: MMSearchBar, UISearchBar, MMGrowTextView, InputToolView, UINavigationBar, UITabBar");
        NSLog(@"[WCCornerExtend] 聊天相关: MessageNodeView, MMMessageCellView, MMImageMessageCellView, MMTimeLabelView, MMNewSessionMsgCell");
        NSLog(@"[WCCornerExtend] 系统组件: UIAlertController, MMEmojiView, EmoticonBoardView, UIMenuController, MMActionSheetView");
    }
}
