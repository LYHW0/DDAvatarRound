//
//  WCRCorner.x  —  模块一：界面圆角（全局卡片化圆角）
//
//  hook 点全部来自原版 LYHW 二进制的初始化函数（__init_offsets → MSHookMessageEx）：
//    MMTableViewCell(layoutSubviews/setFrame:/setBackgroundColor:)
//    MainFrameTableView(initWithFrame:style:/layoutSubviews)
//    NewMainFrameCell(setFrame:/layoutSubviews)
//    MainFrameSectionFoldView(layoutSubviews/setBackgroundColor:)
//    MFBannerBtn(setBackgroundColor:/layoutSubviews) / MFWebMMBtn(layoutSubviews)
//    MMTableSectionHeaderView / MMMainTableView / MMTableView / MMUnderlineTabsView
//    WCToolGroupsBannerView / MMFavImageComponent / FavImagePreview / NewContactsItemCell
//    ThemeBoxSegmentedView / WCSegmentedControl
//
//  效果：把会话列表、通讯录、发现页、收藏页等处的整块列表切成"卡片"，
//  圆角默认 15pt（与原版一致），可配描边、间距、背景色。
//

#import "WCRConfig.h"
#import "WCRCommon.h"

static inline WCRConfig *WCRCfg(void) { return [WCRConfig shared]; }

/// 判断是否该给这个视图上圆角（按板块开关）
static BOOL WCRCornerEnabledForView(UIView *view) {
    if (!view) return NO;
    WCRConfig *cfg = WCRCfg();

    NSString *cls = NSStringFromClass([view class]);
    if ([cls isEqualToString:@"NewMainFrameCell"] ||
        [cls isEqualToString:@"MainFrameTableView"] ||
        [cls isEqualToString:@"MainFrameSectionFoldView"]) {
        return cfg.mainFrameCornerEnabled;
    }
    if ([cls isEqualToString:@"NewContactsItemCell"] ||
        [cls isEqualToString:@"MMTableSectionHeaderView"] ||
        [cls isEqualToString:@"MMMainTableView"]) {
        return cfg.homepageCornerEnabled;
    }
    if ([cls isEqualToString:@"MMFavImageComponent"] || [cls isEqualToString:@"FavImagePreview"]) {
        return cfg.discoverPageCornerEnabled;
    }
    return cfg.homepageCornerEnabled || cfg.mainFrameCornerEnabled;
}

/// 给容器套用卡片样式：圆角 + 描边 + 背景 + 内缩
static void WCRStyleCardView(UIView *view, CGFloat radius, CGFloat inset) {
    if (!view) return;
    WCRConfig *cfg = WCRCfg();

    UIColor *bg = WCRColorForAppearance(cfg.globalCornerBackgroundColorLight,
                                        cfg.globalCornerBackgroundColorDark);
    UIColor *stroke = WCRColorForAppearance(cfg.globalCornerStrokeColorLight,
                                            cfg.globalCornerStrokeColorDark);

    view.backgroundColor = bg;
    WCRApplyCorner(view, radius, cfg.globalCornerStroke, stroke, YES);

    if (inset > 0.01) {
        CGRect b = view.bounds;
        CGRect f = CGRectInset(b, inset, inset * 0.5);
        if (!CGRectEqualToRect(view.bounds, f) && f.size.width > 0) {
            // 只调整内部容器，避免影响外层 cell 复用的 frame 计算
            UIView *inner = view.subviews.firstObject;
            if (inner && !CGRectEqualToRect(inner.frame, f)) {
                inner.frame = f;
            }
        }
    }
}

%hook MMTableViewCell

- (void)layoutSubviews {
    %orig;
    return; // 已由 WCRCellCards.x 统一处理
    UIView *view = (UIView *)self;
    if (!WCRCornerEnabledForView(view)) return;

    WCRConfig *cfg = WCRCfg();
    CGFloat radius = cfg.globalCornerRadius;
    CGFloat margin = cfg.globalCornerMargin;
    UITableViewCell *cell = (UITableViewCell *)view;
    UIView *content = cell.contentView;

    // cell 本身透明，圆角套在 contentView 上，避免把分隔线一起裁掉
    cell.backgroundColor = [UIColor clearColor];
    content.backgroundColor = WCRColorForAppearance(cfg.globalCornerBackgroundColorLight,
                                                      cfg.globalCornerBackgroundColorDark);
    WCRApplyCorner(content, radius, cfg.globalCornerStroke,
                   WCRColorForAppearance(cfg.globalCornerStrokeColorLight,
                                         cfg.globalCornerStrokeColorDark), YES);

    if (@available(iOS 13.0, *)) {
        content.layer.cornerCurve = kCACornerCurveContinuous;
    }

    // 会话列表卡片化：左右留白
    if (margin > 0.01 && content.frame.size.width > margin * 2) {
        CGRect f = content.frame;
        f.origin.x = margin;
        f.size.width = view.bounds.size.width - margin * 2;
        if (fabs(content.frame.origin.x - f.origin.x) > 0.5) {
            content.frame = f;
        }
    }
}

%end

%hook MainFrameTableView

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().mainFrameCornerEnabled) return;
    UITableView *tableView = (UITableView *)self;
    tableView.backgroundColor = [UIColor clearColor];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

%end

%hook NewMainFrameCell

- (void)layoutSubviews {
    %orig;
    return; // 已由 WCRCellCards.x 统一处理
    if (!WCRCfg().mainFrameCornerEnabled) return;

    WCRConfig *cfg = WCRCfg();
    UITableViewCell *cell = (UITableViewCell *)self;
    cell.backgroundColor = [UIColor clearColor];
    UIView *content = cell.contentView;
    content.backgroundColor = WCRColorForAppearance(cfg.globalCornerBackgroundColorLight,
                                                      cfg.globalCornerBackgroundColorDark);
    WCRApplyCorner(content, cfg.globalCornerRadius, cfg.globalCornerStroke,
                   WCRColorForAppearance(cfg.globalCornerStrokeColorLight,
                                         cfg.globalCornerStrokeColorDark), YES);

    CGFloat margin = cfg.globalCornerMargin;
    if (margin > 0.01) {
        CGRect f = content.frame;
        f.origin.x = margin;
        f.size.width = MAX(0, cell.bounds.size.width - margin * 2);
        content.frame = f;
    }
}

%end

%hook MainFrameSectionFoldView

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().mainFrameCornerEnabled) return;
    UIView *fv = (UIView *)self;
    fv.backgroundColor = [UIColor clearColor];
    for (UIView *sv in fv.subviews) if (![sv isKindOfClass:[UIImageView class]] && ![sv isKindOfClass:[UILabel class]]) sv.backgroundColor = [UIColor clearColor];
}

- (void)setBackgroundColor:(UIColor *)color {
    if (WCRCfg().mainFrameCornerEnabled) {
        %orig([UIColor clearColor]);
    } else {
        %orig;
    }
}

%end

%hook MFBannerBtn

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().discoverPageCornerEnabled) return;
    WCRApplyCorner((UIView *)self, WCRCfg().globalCornerRadius, WCRCfg().globalCornerStroke,
                   WCRColorForAppearance(WCRCfg().globalCornerStrokeColorLight,
                                         WCRCfg().globalCornerStrokeColorDark), YES);
}

%end

%hook MFWebMMBtn

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().discoverPageCornerEnabled) return;
    WCRApplyCorner((UIView *)self, WCRCfg().globalCornerRadius, WCRCfg().globalCornerStroke,
                   WCRColorForAppearance(WCRCfg().globalCornerStrokeColorLight,
                                         WCRCfg().globalCornerStrokeColorDark), YES);
}

%end

%hook MMUnderlineTabsView

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().homepageCornerEnabled) return;
    WCRApplyCorner((UIView *)self, WCRCfg().globalCornerRadius, 0, nil, YES);
}

%end

%hook WCToolGroupsBannerView

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().homepageCornerEnabled) return;
    WCRApplyCorner((UIView *)self, WCRCfg().globalCornerRadius, WCRCfg().globalCornerStroke,
                   WCRColorForAppearance(WCRCfg().globalCornerStrokeColorLight,
                                         WCRCfg().globalCornerStrokeColorDark), YES);
}

%end

%hook MMFavImageComponent

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().discoverPageCornerEnabled) return;
    for (UIView *sub in ((UIView *)self).subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            WCRApplyCornerToImageView((UIImageView *)sub, WCRCfg().globalCornerRadius, 0, [UIColor clearColor]);
        }
    }
}

%end

%hook FavImagePreview

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().discoverPageCornerEnabled) return;
    WCRApplyCorner((UIView *)self, WCRCfg().globalCornerRadius, 0, nil, YES);
}

%end

%hook NewContactsItemCell

- (void)layoutSubviews {
    %orig;
    return; // 由 WCRCellCards.x 统一处理
    WCRConfig *cfg = WCRCfg();
    ((UITableViewCell *)self).contentView.backgroundColor = WCRColorForAppearance(cfg.globalCornerBackgroundColorLight,
                                                              cfg.globalCornerBackgroundColorDark);
    WCRApplyCorner(((UITableViewCell *)self).contentView, cfg.globalCornerRadius, cfg.globalCornerStroke,
                   WCRColorForAppearance(cfg.globalCornerStrokeColorLight,
                                         cfg.globalCornerStrokeColorDark), YES);
}

%end

%hook MMTableSectionHeaderView

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().homepageCornerEnabled) return;
    UIView *me = (UIView *)self;
    me.backgroundColor = [UIColor clearColor];
    @try {
        UIView *bi = [me valueForKey:@"backgroundImageView"];
        bi.hidden = YES; bi.alpha = 0;
        for (NSString *k in @[@"topLineView", @"bottomLineView"]) {
            UIView *l = [me valueForKey:k]; l.hidden = YES;
        }
    } @catch (NSException *e) {}
    if ([me respondsToSelector:@selector(backgroundView)]) {
        ((UITableViewHeaderFooterView *)me).backgroundView = nil;
    }
}

%end

%hook ThemeBoxSegmentedView

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().discoverPageCornerEnabled) return;
    WCRApplyCorner((UIView *)self, WCRCfg().globalCornerRadius, 0, nil, YES);
}

%end

%hook WCSegmentedControl

- (void)layoutSubviews {
    %orig;
    if (!WCRCfg().discoverPageCornerEnabled) return;
    WCRApplyCorner((UIView *)self, WCRCfg().globalCornerRadius * 0.6, 0, nil, YES);
}

%end
