//
//  WCRMsgBanner.x  —  模块三：消息横幅美化（微信内新消息横幅）
//
//  原版 hook 点：
//    MMLocalNotificationUtil(showLocalNotificationWithIdentifier:category:title:body:soundName:
//                            badge:userInfo:date:threadIdentifier:fromUserName:showHeadImage:
//                            customHeadImage:)
//    MainFrameLogicController(playNewMsgNotify:NotifyFlag:)
//
//  效果：横幅高度/宽度/外边距/停留时长、正文字数截断、背景图或背景色、
//  标题与正文配色。横幅窗口是系统动态创建的，所以这里用"结构扫描"定位，
//  不依赖固定的私有类名，微信小版本升级也不会直接失效。
//

#import "WCRConfig.h"
#import "WCRCommon.h"

static inline WCRConfig *WCRBCfg(void) { return [WCRConfig shared]; }

static const NSInteger kWCRBannerBgTag = 0x57524342;   // "WRCB"
static const NSInteger kWCRBannerCardTag = 0x57524343; // "WRCC"

/// 从配置目录里取第一张图
static NSString *WCRBannerImagePath(void) {
    NSString *folder = WCRBCfg().msgBannerBgImageFolder;
    if (folder.length == 0) return nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:folder isDirectory:&isDir]) return nil;
    if (!isDir) return folder;

    for (NSString *name in [fm contentsOfDirectoryAtPath:folder error:nil]) {
        NSString *lower = name.lowercaseString;
        if ([lower hasSuffix:@".png"] || [lower hasSuffix:@".jpg"] ||
            [lower hasSuffix:@".jpeg"] || [lower hasSuffix:@".heic"]) {
            return [folder stringByAppendingPathComponent:name];
        }
    }
    return nil;
}

/// 判断一个窗口/视图是不是"消息横幅"
static BOOL WCRLooksLikeBanner(UIView *view) {
    if (!view) return NO;
    NSString *cls = NSStringFromClass([view class]);
    if ([cls containsString:@"Banner"] || [cls containsString:@"Notice"] ||
        [cls containsString:@"Notification"] || [cls containsString:@"Toast"]) {
        // 太小的不算
        return view.bounds.size.width > 100 && view.bounds.size.height > 30;
    }
    return NO;
}

/// 给横幅套样式
static void WCRStyleBannerView(UIView *banner) {
    if (!banner) return;
    WCRConfig *cfg = WCRBCfg();
    if (!cfg.msgBannerBeautifyEnabled) return;

    CGFloat radius = cfg.globalCornerRadius;
    UIColor *stroke = WCRColorForAppearance(cfg.globalCornerStrokeColorLight, cfg.globalCornerStrokeColorDark);

    // 卡片本体（横幅内部通常会有一层容器）
    UIView *card = [banner viewWithTag:kWCRBannerCardTag];
    if (!card) {
        card = banner.subviews.count ? banner.subviews.firstObject : banner;
        card.tag = kWCRBannerCardTag;
    }

    // 尺寸
    CGRect frame = banner.frame;
    if (cfg.msgBannerHeight > 1.0) {
        frame.size.height = cfg.msgBannerHeight;
    }
    CGFloat margin = cfg.msgBannerExtraMargin;
    if (cfg.msgBannerWidth > 1.0) {
        frame.size.width = cfg.msgBannerWidth;
        frame.origin.x = (banner.superview.bounds.size.width - cfg.msgBannerWidth) / 2.0;
    } else if (margin > 0.01) {
        frame.origin.x = margin;
        frame.size.width = banner.superview.bounds.size.width - margin * 2;
    }
    if (!CGRectEqualToRect(frame, banner.frame)) {
        banner.frame = frame;
    }

    // 背景色
    if (cfg.msgBannerBgColorEnabled) {
        banner.backgroundColor = WCRColorForAppearance(cfg.msgBannerBgColorLight, cfg.msgBannerBgColorDark);
    }

    // 背景图
    if (cfg.msgBannerBgUseImageBackground) {
        UIImage *image = nil;
        NSString *path = WCRBannerImagePath();
        if (path) image = [UIImage imageWithContentsOfFile:path];

        UIImageView *bg = (UIImageView *)[banner viewWithTag:kWCRBannerBgTag];
        if (image) {
            if (!bg) {
                bg = [[UIImageView alloc] initWithFrame:banner.bounds];
                bg.tag = kWCRBannerBgTag;
                bg.contentMode = UIViewContentModeScaleAspectFill;
                bg.clipsToBounds = YES;
                bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                bg.userInteractionEnabled = NO;
                [banner insertSubview:bg atIndex:0];
            }
            bg.frame = CGRectOffset(banner.bounds, cfg.msgBannerBgImageOffsetX, cfg.msgBannerBgImageOffsetY);
            bg.image = image;
            bg.alpha = cfg.msgBannerBgImageAlpha;
        }
    }

    // 圆角 + 描边
    WCRApplyCorner(banner, radius, cfg.globalCornerStroke, stroke, YES);
    if (card != banner) {
        WCRApplyCorner(card, radius, 0, nil, YES);
    }

    // 文字配色：标题（字号偏大）用昵称色，正文用内容色
    UIColor *nameColor = WCRColorForAppearance(cfg.msgBannerNicknameColorLight, cfg.msgBannerNicknameColorDark);
    UIColor *contentColor = WCRColorForAppearance(cfg.msgBannerContentColorLight, cfg.msgBannerContentColorDark);

    __block void (^walk)(UIView *);
    __weak __typeof__(walk) weakWalk = nil;
    walk = ^(UIView *v) {
        if ([v isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)v;
            if (cfg.msgBannerNicknameColorEnabled && label.font.pointSize >= 15.0) {
                label.textColor = nameColor;
            }
            if (cfg.msgBannerContentColorEnabled && label.font.pointSize < 15.0) {
                label.textColor = contentColor;
            }
        }
        void (^recurse)(UIView *) = weakWalk;
        for (UIView *sub in v.subviews) {
            if (recurse) recurse(sub);
        }
    };
    weakWalk = walk;
    walk(banner);
}

/// 横幅出现后扫一遍窗口，找到就上样式
static void WCRRestyleVisibleBanners(void) {
    if (!WCRBCfg().msgBannerBeautifyEnabled) return;

    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.hidden || window.alpha < 0.01) continue;
        if (WCRLooksLikeBanner(window)) {
            WCRStyleBannerView(window);
            continue;
        }
        // 横幅通常挂在独立 window 上，往下探两层
        for (UIView *sub in window.subviews) {
            if (WCRLooksLikeBanner(sub)) {
                WCRStyleBannerView(sub);
            }
        }
    }
}

/// 正文截断
static NSString *WCRTruncateBannerBody(NSString *body) {
    WCRConfig *cfg = WCRBCfg();
    if (!cfg.msgBannerBeautifyEnabled) return body;
    if (cfg.msgBannerMaxTextLength <= 0) return body;
    if (body.length <= (NSUInteger)cfg.msgBannerMaxTextLength) return body;

    NSUInteger max = (NSUInteger)cfg.msgBannerMaxTextLength;
    return [[body substringToIndex:max] stringByAppendingString:cfg.msgBannerMaxTextOverflowSuffix ?: @"…"];
}

/// 定时补样式（横幅有动画，出现后会连续回调）
static void WCRScheduleBannerRestyle(void) {
    if (!WCRBCfg().msgBannerBeautifyEnabled) return;

    for (NSNumber *delay in @[@0.05, @0.15, @0.35]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            WCRRestyleVisibleBanners();
        });
    }
}

%hook MMLocalNotificationUtil

+ (void)showLocalNotificationWithIdentifier:(id)identifier
                                   category:(id)category
                                      title:(id)title
                                       body:(id)body
                                  soundName:(id)sound
                                     badge:(id)badge
                                   userInfo:(id)userInfo
                                       date:(id)date
                           threadIdentifier:(id)threadId
                               fromUserName:(id)userName
                               showHeadImage:(BOOL)showHead {
    if (!WCRBCfg().msgBannerBeautifyEnabled) {
        %orig;
        return;
    }
    %orig(identifier, category, title, WCRTruncateBannerBody(body), sound, badge,
          userInfo, date, threadId, userName, showHead);
    WCRScheduleBannerRestyle();
}

+ (void)showLocalNotificationWithIdentifier:(id)identifier
                                   category:(id)category
                                      title:(id)title
                                       body:(id)body
                                  soundName:(id)sound
                                     badge:(id)badge
                                   userInfo:(id)userInfo
                                       date:(id)date
                           threadIdentifier:(id)threadId
                               fromUserName:(id)userName
                               showHeadImage:(BOOL)showHead
                             customHeadImage:(id)customHead {
    if (!WCRBCfg().msgBannerBeautifyEnabled) {
        %orig;
        return;
    }
    %orig(identifier, category, title, WCRTruncateBannerBody(body), sound, badge,
          userInfo, date, threadId, userName, showHead, customHead);
    WCRScheduleBannerRestyle();
}

%end

%hook MainFrameLogicController

- (void)playNewMsgNotify:(id)notify NotifyFlag:(long long)flag {
    %orig;
    WCRScheduleBannerRestyle();
}

%end
