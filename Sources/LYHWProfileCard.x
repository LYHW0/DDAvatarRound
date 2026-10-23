//
//  LYHWProfileCard.x  —  模块二：资料卡美化（联系人资料页 / 名片页）
//
//  原版 hook 点：
//    ContactInfoViewController(viewDidLoad / viewWillAppear: / viewDidLayoutSubviews)
//    WCTimeLineCellView(showContactInfo / showProfileForUser:)  —— 朋友圈点进资料卡
//    WCCommentDetailViewControllerFB(onHeadImageClicked:)
//
//  效果：资料卡背景图/背景色、卡片圆角（可跟随全局圆角）、
//  昵称与签名配色、微信号默认隐藏。
//

#import "LYHWConfig.h"
#import "LYHWCommon.h"

static inline LYHWConfig *LYHWPCfg(void) { return [LYHWConfig shared]; }

static const NSInteger kWCRProfileBackgroundTag = 0x57524350; // "WRCP"

static CGFloat LYHWProfileCornerRadius(void) {
    LYHWConfig *cfg = LYHWPCfg();
    if (cfg.profileFollowGlobalCornerEnabled) {
        return cfg.globalCornerRadius;
    }
    return cfg.profileCornerRadius;
}

/// 给资料卡铺背景（图片优先，其次纯色）
static void LYHWApplyProfileBackground(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded) return;
    LYHWConfig *cfg = LYHWPCfg();
    if (!cfg.profileCardBeautifyEnabled) return;

    UIView *root = vc.view;

    // 纯色背景
    root.backgroundColor = LYHWColorForAppearance(cfg.profileCardBackgroundLightColor,
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
static void LYHWApplyProfileCardCorner(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded) return;
    LYHWConfig *cfg = LYHWPCfg();
    if (!cfg.profileCornerEnabled || YES) return;

    CGFloat radius = LYHWProfileCornerRadius();
    UIView *root = vc.view;

    // 资料页主体是一个 UITableView（或包了一层容器），逐个裁圆角
    for (UIView *sub in root.subviews) {
        if ([sub isKindOfClass:[UITableView class]]) {
            UITableView *table = (UITableView *)sub;
            table.backgroundColor = [UIColor clearColor];
            table.separatorStyle = UITableViewCellSeparatorStyleNone;

            for (UIView *cell in table.subviews) {
                if ([NSStringFromClass([cell class]) containsString:@"Cell"]) {
                    LYHWApplyCorner(((UITableViewCell *)cell).contentView, radius, 0, nil, YES);
                }
            }
        } else if ([NSStringFromClass([sub class]) containsString:@"Header"]) {
            LYHWApplyCorner(sub, radius, 0, nil, YES);
        }
    }
}

/// 昵称 / 签名配色
static void LYHWApplyProfileColors(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded) return;
    LYHWConfig *cfg = LYHWPCfg();
    if (!cfg.profileCardBeautifyEnabled) return;

    UIColor *nameColor = LYHWColorForAppearance(cfg.profileCardNameLightColor, cfg.profileCardNameDarkColor);
    UIColor *signColor = LYHWColorForAppearance(cfg.profileCardSignatureLightColor, cfg.profileCardSignatureDarkColor);

    __block void (^walk)(UIView *);
    __weak __typeof__(walk) weakWalk = nil;
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
        void (^recurse)(UIView *) = weakWalk;
        for (UIView *sub in view.subviews) {
            if (recurse) recurse(sub);
        }
    };
    weakWalk = walk;
    walk(vc.view);
}

%hook ContactInfoViewController

- (void)viewDidLoad {
    %orig;
    UIViewController *controller = (UIViewController *)self;
    LYHWApplyProfileBackground(controller);
    LYHWApplyProfileCardCorner(controller);
    LYHWApplyProfileColors(controller);
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    LYHWApplyProfileBackground((UIViewController *)self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    LYHWApplyProfileBackground((UIViewController *)self);
    LYHWApplyProfileCardCorner((UIViewController *)self);
}

%end

%hook WCTimeLineCellView

- (void)showContactInfo {
    %orig;
}

%end
