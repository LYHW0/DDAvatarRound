//
//  WCRProfileCard.x  —  模块二：资料卡美化（联系人资料页 / 名片页）
//
//  原版 hook 点：
//    ContactInfoViewController(viewDidLoad / viewWillAppear: / viewDidLayoutSubviews)
//    WCTimeLineCellView(showContactInfo / showProfileForUser:)  —— 朋友圈点进资料卡
//    WCCommentDetailViewControllerFB(onHeadImageClicked:)
//
//  效果：资料卡背景图/背景色、卡片圆角（可跟随全局圆角）、
//  昵称与签名配色、微信号默认隐藏。
//

#import "WCRConfig.h"
#import "WCRCommon.h"

static inline WCRConfig *WCRPCfg(void) { return [WCRConfig shared]; }

static const NSInteger kWCRProfileBackgroundTag = 0x57524350; // "WRCP"

static CGFloat WCRProfileCornerRadius(void) {
    WCRConfig *cfg = WCRPCfg();
    if (cfg.profileFollowGlobalCornerEnabled) {
        return cfg.globalCornerRadius;
    }
    return cfg.profileCornerRadius;
}

/// 给资料卡铺背景（图片优先，其次纯色）
static void WCRApplyProfileBackground(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded) return;
    WCRConfig *cfg = WCRPCfg();
    if (!cfg.profileCardBeautifyEnabled) return;

    UIView *root = vc.view;

    // 纯色背景
    root.backgroundColor = WCRColorForAppearance(cfg.profileCardBackgroundLightColor,
                                                 cfg.profileCardBackgroundDarkColor);

    // 背景图
    NSString *path = cfg.profileCardBackgroundImagePath;
    UIImage *image = (path.length > 0) ? [UIImage imageWithContentsOfFile:path] : nil;
    if (!image) return;

    UIImageView *bg = (UIImageView *)[root viewWithTag:kWCRProfileBackgroundTag];
    if (!bg) {
        bg = [[UIImageView alloc] initWithFrame:root.bounds];
        bg.tag = kWCRProfileBackgroundTag;
        bg.contentMode = UIViewContentModeScaleAspectFill;
        bg.clipsToBounds = YES;
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        bg.userInteractionEnabled = NO;
        [root insertSubview:bg atIndex:0];
    }
    bg.frame = root.bounds;
    bg.image = image;
    bg.alpha = cfg.profileCardBackgroundImageAlpha;
}

/// 给资料卡里的"卡片"上圆角
static void WCRApplyProfileCardCorner(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded) return;
    WCRConfig *cfg = WCRPCfg();
    if (!cfg.profileCornerEnabled) return;

    CGFloat radius = WCRProfileCornerRadius();
    UIView *root = vc.view;

    // 资料页主体是一个 UITableView（或包了一层容器），逐个裁圆角
    for (UIView *sub in root.subviews) {
        if ([sub isKindOfClass:[UITableView class]]) {
            UITableView *table = (UITableView *)sub;
            table.backgroundColor = [UIColor clearColor];
            table.separatorStyle = UITableViewCellSeparatorStyleNone;

            for (UIView *cell in table.subviews) {
                if ([NSStringFromClass([cell class]) containsString:@"Cell"]) {
                    WCRApplyCorner(cell.contentView, radius, 0, nil, YES);
                }
            }
        } else if ([NSStringFromClass([sub class]) containsString:@"Header"]) {
            WCRApplyCorner(sub, radius, 0, nil, YES);
        }
    }
}

/// 昵称 / 签名配色
static void WCRApplyProfileColors(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded) return;
    WCRConfig *cfg = WCRPCfg();
    if (!cfg.profileCardBeautifyEnabled) return;

    UIColor *nameColor = WCRColorForAppearance(cfg.profileCardNameLightColor, cfg.profileCardNameDarkColor);
    UIColor *signColor = WCRColorForAppearance(cfg.profileCardSignatureLightColor, cfg.profileCardSignatureDarkColor);

    __block void (^walk)(UIView *);
    walk = ^(UIView *view) {
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            if (label.font.pointSize >= 18.0) {
                label.textColor = nameColor;
            } else if (label.font.pointSize > 0) {
                label.textColor = signColor;
            }

            // 微信号默认隐藏
            if (cfg.profileCardWechatIDHiddenByDefault &&
                [label.text containsString:@"微信号"]) {
                label.hidden = YES;
            }
        }
        for (UIView *sub in view.subviews) {
            walk(sub);
        }
    };
    walk(vc.view);
}

%hook ContactInfoViewController

- (void)viewDidLoad {
    %orig;
    WCRApplyProfileBackground(self);
    WCRApplyProfileCardCorner(self);
    WCRApplyProfileColors(self);
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    WCRApplyProfileBackground(self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    WCRApplyProfileBackground(self);
    WCRApplyProfileCardCorner(self);
}

%end

%hook WCTimeLineCellView

- (void)showContactInfo {
    %orig;
}

%end
