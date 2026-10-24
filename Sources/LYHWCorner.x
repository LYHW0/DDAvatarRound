//
//  LYHWCorner.x  —  模块一：界面圆角（全局卡片化圆角）
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

#import "LYHWConfig.h"
#import "LYHWCommon.h"

static inline LYHWConfig *LYHWCfg(void) { return [LYHWConfig shared]; }

/// 判断是否该给这个视图上圆角（按板块开关）
static BOOL LYHWCornerEnabledForView(UIView *view) {
    if (!view) return NO;
    LYHWConfig *cfg = LYHWCfg();

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
    if ([cls isEqualToString:@"MMFavImageComponent"] || [cls isEqualToString:@"FavImagePreView"]) {
        return cfg.discoverPageCornerEnabled;
    }
    return cfg.homepageCornerEnabled || cfg.mainFrameCornerEnabled;
}

/// 给容器套用卡片样式：圆角 + 描边 + 背景 + 内缩
static void LYHWStyleCardView(UIView *view, CGFloat radius, CGFloat inset) {
    if (!view) return;
    LYHWConfig *cfg = LYHWCfg();

    UIColor *bg = LYHWColorForAppearance(cfg.globalCornerBackgroundColorLight,
                                        cfg.globalCornerBackgroundColorDark);
    UIColor *stroke = LYHWColorForAppearance(cfg.globalCornerStrokeColorLight,
                                            cfg.globalCornerStrokeColorDark);

    view.backgroundColor = bg;
    LYHWApplyCorner(view, radius, cfg.globalCornerStroke, stroke, YES);

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
    return; // 已由 LYHWCellCards.x 统一处理
    UIView *view = (UIView *)self;
    if (!LYHWCornerEnabledForView(view)) return;

    LYHWConfig *cfg = LYHWCfg();
    CGFloat radius = cfg.globalCornerRadius;
    CGFloat margin = cfg.globalCornerMargin;
    UITableViewCell *cell = (UITableViewCell *)view;
    UIView *content = cell.contentView;

    // cell 本身透明，圆角套在 contentView 上，避免把分隔线一起裁掉
    cell.backgroundColor = [UIColor clearColor];
    content.backgroundColor = LYHWColorForAppearance(cfg.globalCornerBackgroundColorLight,
                                                      cfg.globalCornerBackgroundColorDark);
    LYHWApplyCorner(content, radius, cfg.globalCornerStroke,
                   LYHWColorForAppearance(cfg.globalCornerStrokeColorLight,
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

// MainFrameTableView surface is owned by LYHWCellCards.x.
// Do not install a second layout hook that resets its gray surface to clear:
// parent UITableView layout styles visible cards first, then this old override
// used to undo their table background on every layout pass.


%hook NewMainFrameCell

- (void)layoutSubviews {
    %orig;
    return; // 已由 LYHWCellCards.x 统一处理
    if (!LYHWCfg().mainFrameCornerEnabled) return;

    LYHWConfig *cfg = LYHWCfg();
    UITableViewCell *cell = (UITableViewCell *)self;
    cell.backgroundColor = [UIColor clearColor];
    UIView *content = cell.contentView;
    content.backgroundColor = LYHWColorForAppearance(cfg.globalCornerBackgroundColorLight,
                                                      cfg.globalCornerBackgroundColorDark);
    LYHWApplyCorner(content, cfg.globalCornerRadius, cfg.globalCornerStroke,
                   LYHWColorForAppearance(cfg.globalCornerStrokeColorLight,
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
    if (!LYHWCfg().mainFrameCornerEnabled) return;
    UIView *fv = (UIView *)self;
    fv.backgroundColor = [UIColor clearColor];
    for (UIView *sv in fv.subviews) if (![sv isKindOfClass:[UIImageView class]] && ![sv isKindOfClass:[UILabel class]]) sv.backgroundColor = [UIColor clearColor];
}

- (void)setBackgroundColor:(UIColor *)color {
    if (LYHWCfg().mainFrameCornerEnabled) {
        %orig([UIColor clearColor]);
    } else {
        %orig;
    }
}

%end

%hook MFBannerBtn

- (void)layoutSubviews {
    %orig;
    if (!LYHWCfg().discoverPageCornerEnabled) return;
    LYHWApplyCorner((UIView *)self, LYHWCfg().globalCornerRadius, LYHWCfg().globalCornerStroke,
                   LYHWColorForAppearance(LYHWCfg().globalCornerStrokeColorLight,
                                         LYHWCfg().globalCornerStrokeColorDark), YES);
}

%end

%hook MFWebMMBtn

- (void)layoutSubviews {
    %orig;
    if (!LYHWCfg().discoverPageCornerEnabled) return;
    LYHWApplyCorner((UIView *)self, LYHWCfg().globalCornerRadius, LYHWCfg().globalCornerStroke,
                   LYHWColorForAppearance(LYHWCfg().globalCornerStrokeColorLight,
                                         LYHWCfg().globalCornerStrokeColorDark), YES);
}

%end

%hook MMUnderlineTabsView

- (void)layoutSubviews {
    %orig;
    if (!LYHWCfg().homepageCornerEnabled) return;
    LYHWApplyCorner((UIView *)self, LYHWCfg().globalCornerRadius, 0, nil, YES);
}

%end

%hook WCToolGroupsBannerView

- (void)layoutSubviews {
    %orig;
    if (!LYHWCfg().homepageCornerEnabled) return;
    LYHWApplyCorner((UIView *)self, LYHWCfg().globalCornerRadius, LYHWCfg().globalCornerStroke,
                   LYHWColorForAppearance(LYHWCfg().globalCornerStrokeColorLight,
                                         LYHWCfg().globalCornerStrokeColorDark), YES);
}

%end

%hook MMFavImageComponent

- (void)layoutSubviews {
    %orig;
    if (!LYHWCfg().discoverPageCornerEnabled) return;
    for (UIView *sub in ((UIView *)self).subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            LYHWApplyCornerToImageView((UIImageView *)sub, LYHWCfg().globalCornerRadius, 0, [UIColor clearColor]);
        }
    }
}

%end

%hook FavImagePreView

- (void)layoutSubviews {
    %orig;
    if (!LYHWCfg().discoverPageCornerEnabled) return;
    LYHWApplyCorner((UIView *)self, LYHWCfg().globalCornerRadius, 0, nil, YES);
}

%end

%hook NewContactsItemCell

- (void)layoutSubviews {
    %orig;
    return; // 由 LYHWCellCards.x 统一处理
    LYHWConfig *cfg = LYHWCfg();
    ((UITableViewCell *)self).contentView.backgroundColor = LYHWColorForAppearance(cfg.globalCornerBackgroundColorLight,
                                                              cfg.globalCornerBackgroundColorDark);
    LYHWApplyCorner(((UITableViewCell *)self).contentView, cfg.globalCornerRadius, cfg.globalCornerStroke,
                   LYHWColorForAppearance(cfg.globalCornerStrokeColorLight,
                                         cfg.globalCornerStrokeColorDark), YES);
}

%end

%hook MMTableSectionHeaderView

- (void)layoutSubviews {
    %orig;
    if (!LYHWCfg().homepageCornerEnabled) return;
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
    if (!LYHWCfg().discoverPageCornerEnabled) return;
    LYHWApplyCorner((UIView *)self, LYHWCfg().globalCornerRadius, 0, nil, YES);
}

%end

%hook WCSegmentedControl

- (void)layoutSubviews {
    %orig;
    if (!LYHWCfg().discoverPageCornerEnabled) return;
    LYHWApplyCorner((UIView *)self, LYHWCfg().globalCornerRadius * 0.6, 0, nil, YES);
}

%end
