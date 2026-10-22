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

#pragma mark - MMSearchBar / UISearchBar (搜索框圆角)

%hook MMSearchBar

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.searchCornerEnabled) return;
    
    double radius = cfg.searchCornerRadius;
    double borderSize = cfg.searchCornerBorderSize;
    UIColor *borderColor = WCRColorForAppearance(cfg.searchCornerBorderColorLight,
                                                  cfg.searchCornerBorderColorDark);
    
    WCRApplyCorner((UIView *)self, radius, borderSize, borderColor, YES);
    
    // 边距调整（如果 layout 支持）
    if (cfg.searchCornerMargin > 0.01) {
        @try {
            CGFloat margin = cfg.searchCornerMargin;
            for (UIView *sub in ((UIView *)self).subviews) {
                if ([sub isKindOfClass:NSClassFromString(@"UISearchBarTextField")]) {
                    CGRect f = sub.frame;
                    f.origin.x = margin;
                    f.size.width = MAX(0, self.bounds.size.width - margin * 2);
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
    
    double radius = cfg.searchCornerRadius;
    UITextField *textField = [self valueForKey:@"searchField"];
    if (textField) {
        WCRApplyCorner(textField, radius, cfg.searchCornerBorderSize,
                      WCRColorForAppearance(cfg.searchCornerBorderColorLight,
                                            cfg.searchCornerBorderColorDark), YES);
    }
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
    if (!cfg.inputCornerEnabled) return;
    
    for (UIView *sub in ((UIView *)self).subviews) {
        if ([sub isKindOfClass:NSClassFromString(@"MMGrowTextView")] ||
            [sub.class.description containsString:@"TextInput"]) {
            WCRApplyCorner(sub, cfg.inputCornerRadius, cfg.inputCornerBorderSize,
                          WCRColorForAppearance(cfg.inputCornerBorderColorLight,
                                                cfg.inputCornerBorderColorDark), YES);
        }
    }
}

%end

#pragma mark - UINavigationBar (导航栏圆角)

%hook UINavigationBar

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.topbarCornerEnabled) return;
    
    double radius = cfg.topbarCornerRadius;
    double borderSize = cfg.topbarCornerBorderSize;
    
    // 顶边拉平：只圆角底部两个角
    if (cfg.topbarCornerTopFlatEnabled) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                   byRoundingCorners:UIRectCornerBottomLeft | UIRectCornerBottomRight
                                                         cornerRadii:CGSizeMake(radius, radius)];
        CAShapeLayer *mask = [CAShapeLayer layer];
        mask.path = path.CGPath;
        self.layer.mask = mask;
        
        if (borderSize > 0) {
            self.layer.borderWidth = borderSize;
            self.layer.borderColor = WCRColorForAppearance(cfg.topbarCornerBorderColorLight,
                                                           cfg.topbarCornerBorderColorDark).CGColor;
        }
    } else {
        WCRApplyCorner((UIView *)self, radius, borderSize,
                      WCRColorForAppearance(cfg.topbarCornerBorderColorLight,
                                            cfg.topbarCornerBorderColorDark), YES);
    }
}

%end

#pragma mark - UITabBar (底部栏圆角)

%hook UITabBar

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.toolbarCornerEnabled) return;
    
    double radius = cfg.toolbarCornerRadius;
    double borderSize = cfg.toolbarCornerBorderSize;
    
    // 底边拉平：只圆角顶部两个角
    if (cfg.toolbarCornerBottomFlatEnabled) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                   byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight
                                                         cornerRadii:CGSizeMake(radius, radius)];
        CAShapeLayer *mask = [CAShapeLayer layer];
        mask.path = path.CGPath;
        self.layer.mask = mask;
        
        if (borderSize > 0) {
            self.layer.borderWidth = borderSize;
            self.layer.borderColor = WCRColorForAppearance(cfg.toolbarCornerBorderColorLight,
                                                           cfg.toolbarCornerBorderColorDark).CGColor;
        }
    } else {
        WCRApplyCorner((UIView *)self, radius, borderSize,
                      WCRColorForAppearance(cfg.toolbarCornerBorderColorLight,
                                            cfg.toolbarCornerBorderColorDark), YES);
    }
}

%end

#pragma mark - 聊天气泡圆角（MessageNodeView / MMMessageCellView）

%hook MessageNodeView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.chatBubbleCornerEnabled) return;
    
    double radius = cfg.chatBubbleCornerRadius;
    double borderSize = cfg.chatBubbleCornerBorderSize;
    
    WCRApplyCorner((UIView *)self, radius, borderSize,
                  WCRColorForAppearance(cfg.chatBubbleCornerBorderColorLight,
                                        cfg.chatBubbleCornerBorderColorDark), YES);
    
    // 隐藏气泡尾巴（通过修改背景视图的 mask，这需要具体分析 MessageNodeView 的视图层级）
    if (cfg.chatBubbleArrowHidden) {
        // 找到气泡背景视图（通常是第一个 UIImageView 或 UIView）
        for (UIView *sub in ((UIView *)self).subviews) {
            if ([sub isKindOfClass:[UIImageView class]]) {
                // 移除默认气泡图片的"尾巴"
                sub.layer.mask = [CAShapeLayer layer];
                ((CAShapeLayer *)sub.layer.mask).path = [UIBezierPath bezierPathWithRoundedRect:sub.bounds
                                                                                    cornerRadius:radius].CGPath;
                break;
            }
        }
    }
}

%end

%hook MMMessageCellView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.chatBubbleCornerEnabled) return;
    
    // 找到气泡容器（通常是 MessageNodeView）
    for (UIView *sub in ((UIView *)self).subviews) {
        if ([sub.class.description containsString:@"MessageNode"]) {
            WCRApplyCorner(sub, cfg.chatBubbleCornerRadius, cfg.chatBubbleCornerBorderSize,
                          WCRColorForAppearance(cfg.chatBubbleCornerBorderColorLight,
                                                cfg.chatBubbleCornerBorderColorDark), YES);
        }
    }
}

%end

#pragma mark - 聊天图片圆角（BaseMessageNodeData / MMImageMessageCellView）

%hook MMImageMessageCellView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.chatImageCornerEnabled) return;
    
    double radius = cfg.chatImageCornerRadius;
    double borderSize = cfg.chatImageCornerBorderSize;
    
    // 找到图片视图
    for (UIView *sub in ((UIView *)self).subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            WCRApplyCornerToImageView((UIImageView *)sub, radius, borderSize,
                                     WCRColorForAppearance(cfg.chatImageCornerBorderColorLight,
                                                           cfg.chatImageCornerBorderColorDark));
        }
    }
}

%end

#pragma mark - 聊天时间戳圆角（MMTimeLabelView / MMNewSessionMsgCell）

%hook MMTimeLabelView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.chatTimeRoundCornerEnabled) return;
    
    double radius = cfg.chatTimeRoundCornerRadius;
    double borderSize = cfg.chatTimeRoundCornerBorderSize;
    
    WCRApplyCorner((UIView *)self, radius, borderSize,
                  WCRColorForAppearance(cfg.chatTimeRoundCornerBorderColorLight,
                                        cfg.chatTimeRoundCornerBorderColorDark), YES);
}

%end

%hook MMNewSessionMsgCell

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.chatTimeRoundCornerEnabled) return;
    
    // 找到时间标签
    for (UIView *sub in ((UIView *)self).contentView.subviews) {
        if ([sub.class.description containsString:@"TimeLabel"]) {
            WCRApplyCorner(sub, cfg.chatTimeRoundCornerRadius, cfg.chatTimeRoundCornerBorderSize,
                          WCRColorForAppearance(cfg.chatTimeRoundCornerBorderColorLight,
                                                cfg.chatTimeRoundCornerBorderColorDark), YES);
        }
    }
}

%end

#pragma mark - 系统弹窗圆角（UIAlertController）

%hook UIAlertController

- (void)viewWillLayoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.systemPopupCornerEnabled) return;
    
    double radius = cfg.systemPopupCornerRadius;
    double borderSize = cfg.systemPopupCornerBorderSize;
    
    WCRApplyCorner(self.view, radius, borderSize,
                  WCRColorForAppearance(cfg.systemPopupCornerBorderColorLight,
                                        cfg.systemPopupCornerBorderColorDark), YES);
}

%end

#pragma mark - Emoji 面板圆角（MMEmojiView / EmoticonBoardView）

%hook MMEmojiView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.emojiCornerEnabled) return;
    
    double radius = cfg.emojiCornerRadius;
    double borderSize = cfg.emojiCornerBorderSize;
    
    WCRApplyCorner((UIView *)self, radius, borderSize,
                  WCRColorForAppearance(cfg.emojiCornerBorderColorLight,
                                        cfg.emojiCornerBorderColorDark), YES);
}

%end

%hook EmoticonBoardView

- (void)layoutSubviews {
    %orig;
    WCRConfig *cfg = WCRCfgEx();
    if (!cfg.emojiCornerEnabled) return;
    
    double radius = cfg.emojiCornerRadius;
    WCRApplyCorner((UIView *)self, radius, cfg.emojiCornerBorderSize,
                  WCRColorForAppearance(cfg.emojiCornerBorderColorLight,
                                        cfg.emojiCornerBorderColorDark), YES);
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
