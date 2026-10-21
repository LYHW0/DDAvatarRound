//
//  WCRMenu.x  —  模块四：菜单美化（长按菜单 / 加号菜单 / 右键菜单）
//
//  原版 hook 点：
//    MMMenuContentView(addSeparatorLineInY:left:right: / layoutSubviews)
//    MMMenuController(menuView)  —— 菜单容器
//    UITableView(separatorStyle/separatorColor) —— 菜单里的分隔线
//
//  效果：菜单整体圆角、背景色/背景图、文字色、图标色、宽度与每行个数、去掉分割线。
//

#import "WCRConfig.h"
#import "WCRCommon.h"

static inline WCRConfig *WCRMCfg(void) { return [WCRConfig shared]; }

static NSString *WCRMenuBackgroundImagePath(void) {
    NSString *folder = WCRMCfg().menuBackgroundImageFolder;
    if (folder.length == 0) return nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:folder isDirectory:&isDir]) return nil;
    if (!isDir) return folder;

    NSArray<NSString *> *names = [fm contentsOfDirectoryAtPath:folder error:nil];
    for (NSString *name in names) {
        NSString *lower = name.lowercaseString;
        if ([lower hasSuffix:@".png"] || [lower hasSuffix:@".jpg"] ||
            [lower hasSuffix:@".jpeg"] || [lower hasSuffix:@".heic"]) {
            return [folder stringByAppendingPathComponent:name];
        }
    }
    return nil;
}

/// 给菜单容器上样式
static void WCRStyleMenuContainer(UIView *view, BOOL plusMenu) {
    if (!view) return;
    WCRConfig *cfg = WCRMCfg();

    BOOL cornerOn = plusMenu ? cfg.plusMenuCornerEnabled : cfg.menuCornerEnabled;
    CGFloat radius = plusMenu ? cfg.plusMenuCornerRadius : cfg.menuCornerRadius;
    CGFloat borderSize = plusMenu ? cfg.plusMenuBorderSize : cfg.menuCornerBorderSize;
    UIColor *borderColor = plusMenu
        ? WCRColorForAppearance(cfg.plusMenuBorderColorLight, cfg.plusMenuBorderColorDark)
        : WCRColorForAppearance(cfg.menuCornerBorderColorLight, cfg.menuCornerBorderColorDark);

    if (cornerOn) {
        WCRApplyCorner(view, radius, borderSize, borderColor, YES);
    }

    // 背景色
    if (cfg.menuColorEnabled) {
        view.backgroundColor = WCRColorForAppearance(cfg.menuColorLight, cfg.menuColorDark);
    }

    // 背景图
    if (cfg.menuUseImageBackground) {
        NSString *path = WCRMenuBackgroundImagePath();
        UIImage *image = path ? [UIImage imageWithContentsOfFile:path] : nil;
        if (image) {
            UIImageView *bg = (UIImageView *)[view viewWithTag:0x5752434D]; // "WCRM"
            if (!bg) {
                bg = [[UIImageView alloc] initWithFrame:view.bounds];
                bg.tag = 0x5752434D;
                bg.contentMode = UIViewContentModeScaleAspectFill;
                bg.clipsToBounds = YES;
                bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [view insertSubview:bg atIndex:0];
            }
            bg.frame = view.bounds;
            bg.image = image;
            bg.alpha = cfg.menuBackgroundViewAlpha;

            if (cornerOn) {
                WCRApplyCorner(bg, radius, 0, nil, YES);
            }
        }
    }

    // 文字色
    if (cfg.menuTextColorEnabled) {
        UIColor *textColor = WCRColorForAppearance(cfg.menuTextColorLight, cfg.menuTextColorDark);
        WCRTintLabels(view, textColor, nil);
    }

    // 图标色
    if (cfg.menuIconColorEnabled) {
        UIColor *iconColor = WCRColorForAppearance(cfg.menuIconColorLight, cfg.menuIconColorDark);
        for (UIView *sub in view.subviews) {
            if ([sub isKindOfClass:[UIImageView class]]) {
                UIImageView *iv = (UIImageView *)sub;
                iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                iv.tintColor = iconColor;
            }
        }
    }
}

%hook MMMenuContentView

- (void)layoutSubviews {
    %orig;
    WCRStyleMenuContainer((UIView *)self, NO);

    // 菜单宽度
    WCRConfig *cfg = WCRMCfg();
    UIView *menuView = (UIView *)self;
    if (cfg.menuSizeEnabled && cfg.menuWidth > 0.01) {
        CGRect f = menuView.frame;
        if (fabs(f.size.width - cfg.menuWidth) > 0.5) {
            f.size.width = cfg.menuWidth;
            menuView.frame = f;
        }
    }
}

- (void)addSeparatorLineInY:(double)y left:(double)left right:(double)right {
    // 原版菜单美化本身就带"隐藏分割线"：配了圆角后默认不再绘制
    if (WCRMCfg().menuCornerEnabled) {
        return;
    }
    %orig;
}

%end

%hook MMMenuController

- (void)setMenuStyle:(long long)style {
    %orig;
    if (!WCRMCfg().menuCornerEnabled) return;

    id controller = (id)self;
    UIView *menuView = nil;
    @try {
        menuView = [controller valueForKey:@"menuView"];
    } @catch (NSException *e) { (void)e; }

    if ([menuView isKindOfClass:[UIView class]]) {
        WCRStyleMenuContainer(menuView, NO);
    }
}

%end
