#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "LYHWConfig.h"
#import "LYHWCommon.h"

static inline LYHWConfig *LYHWCCfg(void) { return [LYHWConfig shared]; }

static UIColor *LYHWListGray(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1];
    }];
}


static BOOL LYHWAnyCardOn(void) {
    LYHWConfig *c = LYHWCCfg();
    return c.homepageCornerEnabled || c.mainFrameCornerEnabled ||
           c.discoverPageCornerEnabled || c.myPageCornerEnabled || c.settingPageCornerEnabled ||
           c.timelineCornerEnabled || c.profilePageCornerEnabled ||
           c.servicePageCornerEnabled || c.groupInfoCornerEnabled;
}

static BOOL LYHWClassExcluded(NSString *cls) {
    NSArray *bad = @[@"Input", @"Keyboard", @"SearchBar", @"Emoticon", @"Alert"];
    for (NSString *b in bad) {
        if ([cls rangeOfString:b options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}

static UIColor *LYHWCardFill(void) {
    LYHWConfig *c = LYHWCCfg();
    UIColor *u = LYHWColorForAppearance(c.globalCornerBackgroundColorLight,
                                       c.globalCornerBackgroundColorDark);
    if (!u) return [UIColor secondarySystemBackgroundColor];
    return u;
}

static BOOL LYHWInChatPage(UIView *v) {
    UIResponder *r = v;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            NSString *n = NSStringFromClass([r class]);
            if ([n hasPrefix:@"BaseMsgContent"] || [n hasSuffix:@"MsgContentViewController"] ||
                [n containsString:@"MessageList"]) return YES;
            return NO;
        }
        r = r.nextResponder;
    }
    return NO;
}

static void LYHWHideLines(UITableViewCell *cell) {
    // 只隐藏确认是分割线的视图：精确 UIView/名字含 Line/Separator，无子视图，且已完成布局
    NSArray *hosts = @[cell, cell.contentView];
    for (UIView *host in hosts)
        for (UIView *v in host.subviews) {
            if (v.tag == 0x574352 || v.subviews.count > 0) continue;
            NSString *cn = NSStringFromClass([v class]);
            BOOL nameHit = [cn rangeOfString:@"Separator" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                           [cn rangeOfString:@"Line" options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL plain = [cn isEqualToString:@"UIView"];
            if (!nameHit && !plain) continue;
            CGFloat h = v.bounds.size.height, w = v.bounds.size.width;
            if (h > 0.1 && h <= 1.5 && w >= cell.bounds.size.width * 0.4) v.hidden = YES;
        }
}

static NSInteger LYHWPageKind(UIView *v) { // 1主列表 2通讯录 3我 4发现 0其他
    for (UIResponder *r = v; r; r = r.nextResponder) {
        if (![r isKindOfClass:[UIViewController class]]) continue;
        NSString *n = NSStringFromClass([r class]);
        if ([n containsString:@"WCTimeLineViewController"]) return 5;
        if ([n containsString:@"FindFriend"]) return 4;
        if ([n isEqualToString:@"NewSettingViewController"]) return 6;
        if ([n isEqualToString:@"ContactInfoViewController"]) return 7;
        if ([n isEqualToString:@"ChatRoomInfoViewController"]) return 9;
        if ([n isEqualToString:@"SessionSelectController"] || [n isEqualToString:@"ContactSelectorViewController"] ||
            [n isEqualToString:@"MultiSelectContactsViewController"]) return 0;
        if ([n containsString:@"NewMainFrame"]) return 1;
        if ([n containsString:@"ContactsViewController"]) return 2;
        if ([n hasPrefix:@"MoreViewController"]) return 3;
    }
    return 0;
}

static void LYHWRoundMedia(UIView *root, UIView *v) {
    for (UIView *sv in v.subviews) {
        NSString *cn = NSStringFromClass([sv class]);
        CGSize z = sv.bounds.size;
        BOOL media = [cn rangeOfString:@"WebImageView"].location != NSNotFound || [cn rangeOfString:@"SightView"].location != NSNotFound ||
                     [cn rangeOfString:@"MediaItem"].location != NSNotFound || [cn rangeOfString:@"ImageView"].location != NSNotFound || [sv isKindOfClass:[UIImageView class]];
        if (media && z.width >= 60 && z.height >= 60 && z.width < root.bounds.size.width - 40 && sv.layer.cornerRadius < 1) {
            sv.layer.cornerRadius = LYHWCCfg().timelineMediaCornerRadius; sv.layer.masksToBounds = YES; sv.clipsToBounds = YES;
            if (@available(iOS 13.0, *)) sv.layer.cornerCurve = kCACornerCurveContinuous;
            continue;
        }
        if (media) continue;
        LYHWRoundMedia(root, sv);
    }
}
// 左滑/编辑状态时，cell 会左右位移并露出操作按钮；
// 此时分组阴影宿主会出现在按钮区域，看起来像一块黑底，因此临时隐藏它。
static BOOL LYHWCellIsSwiped(UITableViewCell *cell) {
    if (!cell) return NO;
    if (@available(iOS 11.0, *)) {
        if (cell.accessoryType != UITableViewCellAccessoryNone) {}
    }
    UIView *content = cell.contentView;
    if (content.transform.tx != 0) return YES;
    @try {
        id state = [cell valueForKey:@"swipeState"];
        if ([state respondsToSelector:@selector(unsignedIntegerValue)] &&
            ((id (*)(id, SEL))objc_msgSend)(state, @selector(unsignedIntegerValue)) != 0) return YES;
    } @catch (__unused id e) {}
    for (UIView *sv in cell.subviews) {
        NSString *cn = NSStringFromClass([sv class]);
        if ([cn containsString:@"Swipe"] && !sv.hidden && sv.alpha > 0.01) return YES;
    }
    return NO;
}

// 给内容层套一个与卡片形状完全一致的裁剪遮罩，
// 这样卡片圆角之外不可能再露出任何直角白块。
static void LYHWClipToCard(UITableViewCell *cell, UIView *card) {
    if (!cell || !card) return;
    CALayer *host = cell.contentView.layer;
    CAShapeLayer *mask = nil;
    if ([host.mask isKindOfClass:[CAShapeLayer class]] &&
        [host.mask.name isEqualToString:@"LYHWClipMask"]) mask = (CAShapeLayer *)host.mask;
    if (!mask) {
        mask = [CAShapeLayer layer];
        mask.name = @"LYHWClipMask";
        host.mask = mask;
    }
    CGRect r = [cell convertRect:card.frame fromView:card.superview];
    if (r.size.width < 1 || r.size.height < 1) { host.mask = nil; return; }
    CGFloat rad = card.layer.cornerRadius;
    CACornerMask cm = card.layer.maskedCorners;
    UIBezierPath *path = nil;
    if (rad < 0.5 || cm == 0) {
        path = [UIBezierPath bezierPathWithRect:r];
    } else {
        UIRectCorner uc = 0;
        if (cm & kCALayerMinXMinYCorner) uc |= UIRectCornerTopLeft;
        if (cm & kCALayerMaxXMinYCorner) uc |= UIRectCornerTopRight;
        if (cm & kCALayerMinXMaxYCorner) uc |= UIRectCornerBottomLeft;
        if (cm & kCALayerMaxXMaxYCorner) uc |= UIRectCornerBottomRight;
        path = [UIBezierPath bezierPathWithRoundedRect:r
                                    byRoundingCorners:uc
                                          cornerRadii:CGSizeMake(rad, rad)];
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    mask.frame = host.bounds;
    mask.path = path.CGPath;
    // 白底（backgroundView）不在 contentView 里，单独给它也套同样的遮罩
    CALayer *bgHost = card.layer;
    CAShapeLayer *bgMask = nil;
    if ([bgHost.mask isKindOfClass:[CAShapeLayer class]] &&
        [bgHost.mask.name isEqualToString:@"LYHWBgMask"]) bgMask = (CAShapeLayer *)bgHost.mask;
    if (!bgMask) { bgMask = [CAShapeLayer layer]; bgMask.name = @"LYHWBgMask"; bgHost.mask = bgMask; }
    bgMask.frame = bgHost.bounds;
    CGRect local = card.bounds;
    UIBezierPath *lp = nil;
    if (rad < 0.5 || cm == 0) lp = [UIBezierPath bezierPathWithRect:local];
    else {
        UIRectCorner uc2 = 0;
        if (cm & kCALayerMinXMinYCorner) uc2 |= UIRectCornerTopLeft;
        if (cm & kCALayerMaxXMinYCorner) uc2 |= UIRectCornerTopRight;
        if (cm & kCALayerMinXMaxYCorner) uc2 |= UIRectCornerBottomLeft;
        if (cm & kCALayerMaxXMaxYCorner) uc2 |= UIRectCornerBottomRight;
        lp = [UIBezierPath bezierPathWithRoundedRect:local byRoundingCorners:uc2 cornerRadii:CGSizeMake(rad, rad)];
    }
    bgMask.path = lp.CGPath;
    [CATransaction commit];
}

// 板块阴影：只在**整块圆角板块的最下面**出一层阴影。
//   · 逐行加阴影会在每两行之间多出一条横向暗带，看起来像一条条分割线（用户反馈「太别扭」）；
//   · 现在只让板块最后一行挂阴影，并把阴影形状裁到卡片下缘一条带 ——
//     卡片本身不透明、且压在阴影层上方，条带上半部分的阴影自然被盖住，
//     露出来的只剩圆角板块底部那一圈；
//   · 左滑时整行会移动，阴影留在原地会变成黑块，所以左滑中直接隐藏。
static void LYHWApplyCardShadow(UITableViewCell *cell, UIView *card, LYHWConfig *c, BOOL isBlockBottom) {
    if (!cell || !card) return;
    double st = c.cardShadowEnabled ? MAX(0.0, MIN(1.0, c.cardShadowStrength)) : 0.0;
    UIView *host = [cell viewWithTag:0x574357];
    if (st <= 0.001 || !isBlockBottom || LYHWCellIsSwiped(cell)) {
        if (host) host.hidden = YES;
        return;
    }
    if (!host) {
        host = [UIView new];
        host.tag = 0x574357;
        host.userInteractionEnabled = NO;
        host.backgroundColor = [UIColor clearColor];
        host.layer.shadowColor = [UIColor blackColor].CGColor;
        host.layer.shadowRadius = 7;
        host.layer.shadowOffset = CGSizeMake(0, 3);
    }
    if (host.superview != cell) [cell insertSubview:host atIndex:0];
    if (card.superview == cell && [cell.subviews indexOfObject:host] > [cell.subviews indexOfObject:card])
        [cell insertSubview:host belowSubview:card];
    host.hidden = NO;
    if (!CGRectEqualToRect(host.frame, card.frame)) host.frame = card.frame;
    host.layer.cornerRadius = card.layer.cornerRadius;
    host.layer.maskedCorners = card.layer.maskedCorners;
    if (@available(iOS 13.0, *)) host.layer.cornerCurve = kCACornerCurveContinuous;
    host.layer.shadowOpacity = (float)st;

    CGFloat rad = card.layer.cornerRadius;
    CACornerMask cm = card.layer.maskedCorners;
    CGFloat w = host.bounds.size.width, h = host.bounds.size.height;
    if (w < 1 || h < 1) return;
    CGFloat bandH = MIN(h, 28.0);
    CGRect band = CGRectMake(0, h - bandH, w, bandH);
    UIRectCorner uc = 0;
    if (cm & kCALayerMinXMaxYCorner) uc |= UIRectCornerBottomLeft;
    if (cm & kCALayerMaxXMaxYCorner) uc |= UIRectCornerBottomRight;
    UIBezierPath *path = nil;
    if (rad < 0.5 || uc == 0) path = [UIBezierPath bezierPathWithRect:band];
    else path = [UIBezierPath bezierPathWithRoundedRect:band byRoundingCorners:uc
                                          cornerRadii:CGSizeMake(rad, rad)];
    host.layer.shadowPath = path.CGPath;
}

// 左滑按钮条（原生 UISwipeActionPullView / 微信自绘的 *Swipe*/*Pull* 容器）：
//   · 原生是全通栏、直角、还带一层投影，左滑时看起来像「从屏幕最右边钻出来」，
//     而且那层投影会压在白卡上，在按钮左侧留下一条黑色渐变块；
//   · 这里把它整体收进卡片范围（右缘对齐卡片右缘）、按卡片圆角裁边、去掉投影，
//     并把容器底色里的近黑清成透明 —— 按钮就从圆角框里出来了。
static BOOL LYHWIsSwipeHostView(UIView *v) {
    if (!v) return NO;
    NSString *cn = NSStringFromClass([v class]);
    if (cn.length == 0) return NO;
    if ([cn rangeOfString:@"Swipe" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    if ([cn rangeOfString:@"Pull" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    return NO;
}

static void LYHWApplySwipeGeometry(UIView *v, CGFloat left, CGFloat right, CGFloat rad, CACornerMask cm) {
    if (!v) return;
    CGRect f = v.frame;
    if (f.size.width < 1 || f.size.height < 8) return;
    BOOL changed = NO;
    // ① 右缘收进卡片（宽度不变、整体左移，避免按钮被压扁）
    if (CGRectGetMaxX(f) > right + 0.5) { f.origin.x = right - f.size.width; changed = YES; }
    // ② 左缘不出卡片
    if (f.origin.x < left - 0.5) { f.origin.x = left; changed = YES; }
    if (changed && !CGRectEqualToRect(v.frame, f)) v.frame = f;

    // ③ 按卡片圆角裁边 + 去掉投影 + 清掉近黑底
    CALayer *l = v.layer;
    l.shadowOpacity = 0;
    l.shadowRadius = 0;
    l.shadowOffset = CGSizeZero;
    l.shadowPath = NULL;
    l.masksToBounds = YES;
    l.cornerRadius = rad;
    l.maskedCorners = cm;
    if (@available(iOS 13.0, *)) l.cornerCurve = kCACornerCurveContinuous;
    v.clipsToBounds = YES;

    UIColor *bgc = v.backgroundColor;
    CGFloat w = 0, a = 1;
    if (bgc && [bgc getWhite:&w alpha:&a] && a > 0.02 && w < 0.35) {
        v.backgroundColor = [UIColor clearColor];
        l.backgroundColor = nil;
    }
}

static void LYHWKillShadow(UIView *v) {
    if (!v) return;
    CALayer *l = v.layer;
    l.shadowOpacity = 0;
    l.shadowRadius = 0;
    l.shadowOffset = CGSizeZero;
    l.shadowPath = NULL;
}

// 注意：iOS 11+ 的层级是 cell → _UITableViewCellSwipeContainerView → (contentView, UISwipeActionPullView)。
// 容器本身包着 contentView，**绝不能**改它的 frame/裁剪，否则整行内容都会跟着被裁。
// 所以：包着 contentView 的视图只往里递归（顺手清掉它的投影），真正动手的只有按钮条。
static void LYHWScanSwipeViews(UIView *root, UIView *contentView,
                               CGFloat left, CGFloat right,
                               CGFloat rad, CACornerMask cm, int depth) {
    if (!root || depth > 4) return;
    for (UIView *v in [root.subviews copy]) {
        if (v == contentView) continue;
        if (v.tag == 0x574352 || v.tag == 0x574353 || v.tag == 0x574357) continue;
        BOOL holdsContent = (contentView && [contentView isDescendantOfView:v]);
        if (holdsContent) {
            LYHWKillShadow(v);            // 容器的投影会压在白卡上变成黑边
            LYHWScanSwipeViews(v, contentView, left, right, rad, cm, depth + 1);
            continue;
        }
        if (LYHWIsSwipeHostView(v)) { LYHWApplySwipeGeometry(v, left, right, rad, cm); continue; }
        LYHWScanSwipeViews(v, contentView, left, right, rad, cm, depth + 1);
    }
}

static void LYHWConstrainSwipeViews(UITableViewCell *cell, UIView *card) {
    if (!cell || !card) return;
    CGRect cr = card.frame;
    if (cr.size.width < 1 || cr.size.height < 1) return;
    LYHWScanSwipeViews(cell, cell.contentView,
                       CGRectGetMinX(cr), CGRectGetMaxX(cr),
                       card.layer.cornerRadius, card.layer.maskedCorners, 0);
}

static void LYHWStyleCellCard(UITableViewCell *cell) {
    if (!cell) return;
    if (LYHWClassExcluded(NSStringFromClass([cell class]))) return;
    UITableView *tv = nil;
    for (UIView *v = cell.superview; v; v = v.superview)
        if ([v isKindOfClass:[UITableView class]]) { tv = (UITableView *)v; break; }
    if (!tv || LYHWInChatPage(tv)) return;
    NSIndexPath *ip = [tv indexPathForCell:cell];
    if (!ip) return;

    LYHWConfig *c = LYHWCCfg();
    NSInteger kind = LYHWPageKind(tv);
    if (kind == 0) return;
    BOOL profileLike = (kind == 7 || kind == 9);
    if (kind == 9) { if (!c.groupInfoCornerEnabled) return; kind = 6; }
    if (kind == 7) { if (!c.profilePageCornerEnabled) return; kind = 6; }
    else if (kind == 6 && !c.settingPageCornerEnabled) return;
    BOOL settingPage = (kind == 6);
    if (settingPage) kind = 4;
    BOOL timeline = (kind == 5);
    if (timeline && !c.timelineCornerEnabled) return;
    if (timeline) kind = 1;  // 朋友圈改为和主页一样，每行独立卡片
    if ((kind == 1 && !timeline && !c.mainFrameCornerEnabled) || (kind == 2 && !c.homepageCornerEnabled) ||
        (kind == 3 && !c.myPageCornerEnabled) || (kind == 4 && !settingPage && !c.discoverPageCornerEnabled)) return;
    BOOL fancy = (kind != 4);
        CGFloat radius = kind == 1 ? 22.0 : (kind == 3 ? (c.myPageCornerRadius > 0 ? c.myPageCornerRadius : 24.0) : fancy ? 24.0 : (c.globalCornerRadius > 0 ? c.globalCornerRadius : 28.0));
    CGFloat margin = kind == 1 ? 9.0 : (kind == 2 ? 10.0 : (kind == 3 ? (c.myPageCornerMargin > 0 ? c.myPageCornerMargin : 20.0) : fancy ? 20.0 : (c.globalCornerMargin > 0 ? c.globalCornerMargin : 18.0)));
    if (profileLike) { radius = 24.0; margin = 10.0; }
    NSInteger rows = [tv numberOfRowsInSection:ip.section];
    // 分组范围：通讯录页把连续“无标题”的 section 合并成一块；其它页每个 section 一块
    NSInteger secFirst = ip.section, secLast = ip.section;
    if (kind == 2 && [tv rectForHeaderInSection:ip.section].size.height <= 1.0) {
        NSInteger total = tv.numberOfSections;
        while (secFirst > 0 && [tv rectForHeaderInSection:secFirst].size.height <= 1.0 &&
               [tv numberOfRowsInSection:secFirst - 1] > 0 &&
               [tv rectForHeaderInSection:secFirst - 1].size.height <= 1.0) secFirst--;
        while (secLast < total - 1 && [tv rectForHeaderInSection:secLast + 1].size.height <= 1.0 &&
               [tv numberOfRowsInSection:secLast + 1] > 0) secLast++;
    }
    NSInteger fr = 0, lr = rows - 1;
    CGFloat skipH = timeline ? 14.0 : 1.0;
    while (fr < lr && [tv rectForRowAtIndexPath:[NSIndexPath indexPathForRow:fr inSection:ip.section]].size.height <= skipH) fr++;
    while (lr > fr && [tv rectForRowAtIndexPath:[NSIndexPath indexPathForRow:lr inSection:ip.section]].size.height <= skipH) lr--;
    if (timeline && ip.row > lr) {
        cell.backgroundView = nil; cell.selectedBackgroundView = nil; cell.backgroundColor = [UIColor clearColor];
        cell.contentView.backgroundColor = [UIColor clearColor];
        for (UIView *sv in cell.contentView.subviews) { sv.backgroundColor = [UIColor clearColor]; sv.hidden = YES; }
        return;
    }
    BOOL isFirstRow = (ip.section == secFirst && ip.row <= fr);
    BOOL isLastRow = (ip.section == secLast && ip.row >= lr);

    // 列表底色：浅灰，卡片为白
    UIColor *bg = LYHWListGray();
    tv.backgroundColor = bg;
    tv.separatorStyle = UITableViewCellSeparatorStyleNone;
    tv.sectionIndexBackgroundColor = [UIColor clearColor];
    tv.sectionIndexTrackingBackgroundColor = [UIColor clearColor];
    if (fancy) tv.clipsToBounds = NO;

    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.layer.backgroundColor = [UIColor clearColor].CGColor;
    for (UIView *sv in cell.subviews) {
        if (sv == cell.contentView || sv == cell.backgroundView || sv == cell.selectedBackgroundView || sv.tag == 0x574353) continue;
        if ([NSStringFromClass([sv class]) rangeOfString:@"Separator"].location != NSNotFound) continue;
        if (sv.bounds.size.height >= cell.bounds.size.height * 0.8) { sv.backgroundColor = [UIColor clearColor]; sv.layer.backgroundColor = [UIColor clearColor].CGColor; }
    }
    UIView *card = cell.backgroundView;
    if (!card || card.tag != 0x574352) {
        card = [UIView new];
        card.tag = 0x574352;
        card.userInteractionEnabled = NO;
        cell.backgroundView = card;
    }
    // 同组整块：上下不留缝，只有首尾行有圆角
    card.frame = CGRectMake(margin, 0, cell.bounds.size.width - margin * 2, cell.bounds.size.height);
    card.backgroundColor = LYHWCardFill();
    if (kind == 1 && !timeline) {
        card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor];
        }];
        tv.backgroundView = nil;
        if (tv.superview) {
            tv.superview.backgroundColor = bg;
            NSMutableArray *cands = [NSMutableArray arrayWithArray:tv.superview.subviews];
            [cands addObjectsFromArray:tv.subviews];
            for (UIView *u in cands) {
                if (u == tv || [u isKindOfClass:[UITableViewCell class]] || [u isKindOfClass:[UILabel class]]) continue;
                if (u.bounds.size.width >= tv.bounds.size.width * 0.9 && u.bounds.size.height > 200 && u.subviews.count < 3) {
                    u.backgroundColor = bg; u.layer.backgroundColor = bg.CGColor;
                }
            }
        }
    }
    card.layer.cornerRadius = radius;
    card.layer.masksToBounds = !fancy;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    CACornerMask m = 0;
    if (isFirstRow) m |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (isLastRow) m |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    card.layer.maskedCorners = m;
    BOOL single = NO; (void)single;
    if (timeline) {
        card.layer.cornerRadius = c.timelineCornerRadius;
        CGRect f = card.frame;
        CGFloat top = isFirstRow ? 6 : 0, bot = isLastRow ? 6 : 0;
        f.origin.y = top; f.size.height = cell.bounds.size.height - top - bot;
        card.frame = f;
        if (m == 0) card.layer.cornerRadius = 0;
    } else if (m == 0) card.layer.cornerRadius = 0;
    {
        UIView *sel = cell.selectedBackgroundView;
        if (!sel || sel.tag != 0x574353) {
            sel = [UIView new]; sel.tag = 0x574353; sel.userInteractionEnabled = NO;
            cell.selectedBackgroundView = sel;
        }
        sel.frame = card.frame;
        sel.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            return (t.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.22 alpha:1] : [UIColor colorWithWhite:0.88 alpha:1]);
        }];
        sel.layer.cornerRadius = card.layer.cornerRadius;
        sel.layer.maskedCorners = card.layer.maskedCorners;
        sel.layer.masksToBounds = YES;
        if (@available(iOS 13.0, *)) sel.layer.cornerCurve = kCACornerCurveContinuous;
        cell.multipleSelectionBackgroundView = nil;
    }
    LYHWHideLines(cell);
    if (!timeline && !LYHWCellIsSwiped(cell)) LYHWClipToCard(cell, card);
    else if (timeline) { /* 朋友圈单独处理 */ }
    if (profileLike) {
        // 群聊页真实层级：cell 里有整屏宽（393）的白色视图（非卡片宿主 0x574352），
        // 它的直角会从卡片圆角外露出。这里把它们统一清透明，只保留卡片宿主。
        CGFloat fullW = cell.bounds.size.width;
        NSMutableArray *st = [NSMutableArray arrayWithObject:cell.contentView];
        while (st.count) {
            UIView *v = st.lastObject; [st removeLastObject];
            for (UIView *sv in v.subviews) {
                if (sv == card || sv.tag == 0x574352 || sv.tag == 0x574353 || sv.tag == 0x574354 ||
                    sv.tag == 0x574355 || sv.tag == 0x574356) continue;
                if ([sv isKindOfClass:[UILabel class]] || [sv isKindOfClass:[UIImageView class]] ||
                    [sv isKindOfClass:[UIButton class]]) continue;
                CGFloat w = 0, a = 0;
                BOOL wide = sv.bounds.size.width >= fullW - 1.0 && sv.bounds.size.height > 4;
                BOOL white = sv.backgroundColor && [sv.backgroundColor getWhite:&w alpha:&a] && a > 0.02 && w > 0.9;
                if (wide && white) {
                    sv.backgroundColor = [UIColor clearColor];
                    sv.layer.backgroundColor = nil;
                    sv.layer.cornerRadius = 0;
                }
                if (sv.subviews.count) [st addObject:sv];
            }
        }
    }
    if (profileLike) {
        // 资料页/群聊资料页：cell 的整块白底比卡片宽，左右两侧会露出直角白条，
        // 这里把 cell 本身的背景与 contentView 都收回到卡片宽度范围内。
        CGFloat mg = margin;
        CGRect cf = cell.contentView.frame;
        cell.contentView.clipsToBounds = YES;
        cell.clipsToBounds = NO;
        cell.backgroundColor = [UIColor clearColor];
        if (cf.origin.x != 0) cell.contentView.frame = CGRectMake(0, cf.origin.y, cell.bounds.size.width, cf.size.height);
        card.frame = CGRectMake(mg, 0, cell.bounds.size.width - mg * 2, cell.bounds.size.height);
        for (UIView *sv in cell.subviews) {
            if (sv == cell.contentView || sv == card || sv.tag == 0x574353) continue;
            if (sv.bounds.size.width > cell.bounds.size.width - mg * 2 + 0.5 && sv.bounds.size.height > 4) {
                sv.backgroundColor = [UIColor clearColor];
                sv.layer.backgroundColor = nil;
            }
        }
    }
    if (timeline) {
        if (c.timelineMediaCornerEnabled) LYHWRoundMedia(cell, cell);
        CGFloat cw = cell.bounds.size.width;
        NSMutableArray *st = [NSMutableArray arrayWithObject:cell.contentView];
        while (st.count) {
            UIView *v = st.lastObject; [st removeLastObject];
            for (UIView *sv in v.subviews) {
                if (sv.bounds.size.width >= cw * 0.8 && sv.backgroundColor) {
                    CGFloat w = 0, a = 0;
                    if ([sv.backgroundColor getWhite:&w alpha:&a] && w > 0.97 && a > 0.5) sv.backgroundColor = [UIColor clearColor];
                }
                if (sv.bounds.size.width >= cw * 0.8) [st addObject:sv];
            }
        }
        cell.contentView.layer.cornerRadius = 0;
        cell.clipsToBounds = NO;
    }
    LYHWApplyCardShadow(cell, card, c, isLastRow);
    LYHWConstrainSwipeViews(cell, card);
}



%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    if (!LYHWAnyCardOn()) return;
    LYHWStyleCellCard((UITableViewCell *)self);
}
%end

%hook UICollectionViewCell
- (void)layoutSubviews {
    %orig;
    if (!LYHWAnyCardOn()) return;
    UICollectionViewCell *cell = (UICollectionViewCell *)self;
    NSString *cls = NSStringFromClass([cell class]);
    if (LYHWClassExcluded(cls) || LYHWInChatPage(cell) || LYHWPageKind(cell) != 4) return;
    LYHWConfig *c = LYHWCCfg();
    CGFloat radius = c.globalCornerRadius > 0 ? c.globalCornerRadius : 12.0;
    cell.contentView.layer.cornerRadius = radius;
    cell.contentView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
}
%end

static void LYHWPlace(UIView *v, UIView *h, CGFloat tx, CGFloat ty) {
    v.transform = CGAffineTransformIdentity;
    CGRect f = [v.superview convertRect:v.frame toView:h];
    v.transform = CGAffineTransformMakeTranslation(tx - CGRectGetMidX(f), ty - CGRectGetMidY(f));
}

static CGFloat stopW = 0;
static void LYHWClearBg(UIView *v, UIView *stop) {
    for (UIView *sv in v.subviews) {
        if (sv == stop || sv.tag == 0x574354 || sv.tag == 0x574355) continue;
        CGFloat sw = sv.bounds.size.width, sh = sv.bounds.size.height;
        if (sw >= stopW * 0.82 && sh >= 48) {
            sv.backgroundColor = [UIColor clearColor];
            sv.layer.backgroundColor = nil; sv.layer.cornerRadius = 0;
            if (([sv isKindOfClass:[UIImageView class]] || [sv isKindOfClass:[UIVisualEffectView class]]) && sv.subviews.count == 0) { sv.hidden = YES; continue; }
        }
        if ([sv isKindOfClass:[UILabel class]] || [sv isKindOfClass:[UIImageView class]] || [sv isKindOfClass:[UIButton class]]) continue;
        // 头部里横穿整屏的窄白条（原生分段底色）：刷成列表灰，避免从卡片圆角外露白
        if (sw >= stopW * 0.9 && sh > 1.5 && sh <= 30) {
            CGFloat w = 0, a = 0;
            UIColor *c0 = sv.backgroundColor;
            if (c0 && [c0 getWhite:&w alpha:&a] && a > 0.02 && w > 0.9) {
                sv.backgroundColor = LYHWListGray();
                sv.layer.backgroundColor = nil;
            }
        }
        if (sv.subviews.count > 0 && sv.bounds.size.height > 40) sv.backgroundColor = [UIColor clearColor];
        LYHWClearBg(sv, stop);
    }
}

static void LYHWFlatWhite(UIView *v, UIColor *c, CGFloat W) {
    for (UIView *sv in v.subviews) {
        if ([sv isKindOfClass:[UILabel class]] || [sv isKindOfClass:[UIButton class]]) continue;
        if (sv.bounds.size.width >= W * 0.85 && sv.bounds.size.height >= 60) {
            sv.backgroundColor = c; sv.layer.cornerRadius = 0; sv.layer.backgroundColor = c.CGColor;
        }
        LYHWFlatWhite(sv, c, W);
    }
}
// 只把列表自身及其父视图、头部容器的底色刷成列表灰，
// 不碰卡片、不碰 cell 内部的任何视图，避免把卡片本身清成透明/灰色。
static void LYHWPaintListSurface(UITableView *tv, UIView *header) {
    UIColor *bg = LYHWListGray();
    tv.backgroundColor = bg;
    tv.backgroundView = nil;
    if (header) header.backgroundColor = bg;
    UIView *host = tv.superview;
    if (host) {
        CGFloat w = 0, a = 0;
        UIColor *hc = host.backgroundColor;
        BOOL whiteish = NO;
        if (hc && [hc getWhite:&w alpha:&a]) whiteish = (a > 0.02 && w > 0.9);
        if (whiteish) host.backgroundColor = bg;
    }
}

// 头部里比卡片更宽的白色底块（原生整宽底）会从卡片圆角外露出直角，
// 只清这类视图，绝不碰卡片自身。
static void LYHWClearWiderWhite(UIView *v, CGFloat cardW, UIView *card, int depth) {
    if (depth > 6) return;
    for (UIView *sv in v.subviews) {
        if (sv == card || [sv isDescendantOfView:card]) continue;
        if (sv.tag == 0x574354 || sv.tag == 0x574355 || sv.tag == 0x574356) continue;
        CGFloat sw = sv.bounds.size.width, sh = sv.bounds.size.height;
        if (sw > cardW + 1.0 && sh > 4) {
            CGFloat w = 0, a = 0;
            UIColor *c0 = sv.backgroundColor;
            if (c0 && [c0 getWhite:&w alpha:&a] && a > 0.02 && w > 0.9) {
                sv.backgroundColor = [UIColor clearColor];
                sv.layer.backgroundColor = nil;
            }
        }
        if (![sv isKindOfClass:[UILabel class]] && ![sv isKindOfClass:[UIImageView class]] && ![sv isKindOfClass:[UIButton class]])
            LYHWClearWiderWhite(sv, cardW, card, depth + 1);
    }
}

static void LYHWStyleInfoHeader(UITableView *tv) {
    UIView *h = tv.tableHeaderView;
    if (!h || h.bounds.size.width < 100 || h.bounds.size.height < 60) return;
    CGFloat W = h.bounds.size.width, H = h.bounds.size.height;
    UIView *card = [h viewWithTag:0x574355];
    if (!card) { card = [UIView new]; card.tag = 0x574355; card.userInteractionEnabled = NO; [h insertSubview:card atIndex:0]; }
    card.frame = CGRectMake(10, 4, W - 20, H - 12);
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor]; }];
    card.layer.cornerRadius = 24;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    h.backgroundColor = [UIColor clearColor];
    stopW = W;
    LYHWClearBg(h, card);
    LYHWClearWiderWhite(h, card.bounds.size.width, card, 0);
    LYHWPaintListSurface(tv, h);
}

static void LYHWStyleMyHeader(UITableView *tv) {
    UIView *h = tv.tableHeaderView;
    if (!h || h.bounds.size.width < 100) return;
    CGFloat W = h.bounds.size.width;
    UIView *avatar = nil, *status = nil; NSMutableArray *labels = [NSMutableArray array];
    NSMutableArray *stack = [NSMutableArray arrayWithObject:h];
    while (stack.count) {
        UIView *v = stack.lastObject; [stack removeLastObject];
        for (UIView *sv in v.subviews) {
            NSString *cn = NSStringFromClass([sv class]);
            if (sv.tag == 0x574354) continue;
            if (!avatar && ([cn containsString:@"HeadImage"] || [cn containsString:@"Avatar"])) { avatar = sv; continue; }
            if (!status && ([cn containsString:@"Status"] || [cn containsString:@"TextState"])) { status = sv; continue; }
            if ([sv isKindOfClass:[UILabel class]] && ((UILabel *)sv).text.length) [labels addObject:sv];
            else [stack addObject:sv];
        }
    }
    if (!avatar || labels.count < 2) return;
    [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
        return a.font.pointSize > b.font.pointSize ? NSOrderedAscending : NSOrderedDescending; }];
    UILabel *name = labels[0], *wid = labels[1];
    CGFloat cardTop = -34, cardH = 232, mx = 8;
    h.clipsToBounds = NO;
    UIView *card = [h viewWithTag:0x574354];
    if (!card) { card = [UIView new]; card.tag = 0x574354; card.userInteractionEnabled = NO; [h insertSubview:card atIndex:0]; }
    card.frame = CGRectMake(mx, cardTop, W - mx * 2, cardH);
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor]; }];
    card.layer.cornerRadius = 24;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    h.backgroundColor = [UIColor clearColor];
    stopW = W;
    LYHWClearBg(h, card);
    LYHWClearWiderWhite(h, card.bounds.size.width, card, 0);
    LYHWPaintListSurface(tv, h);
    name.textAlignment = NSTextAlignmentCenter; wid.textAlignment = NSTextAlignmentCenter;
    LYHWPlace(avatar, h, W / 2, cardTop + 62);
    LYHWPlace(name, h, W / 2, cardTop + 128);
    LYHWPlace(wid, h, W / 2, cardTop + 163);
    if (status) {
        UIView *circle = nil;
        NSMutableArray *st2 = [NSMutableArray arrayWithObject:h];
        while (st2.count && !circle) {
            UIView *v = st2.lastObject; [st2 removeLastObject];
            for (UIView *sib in v.subviews) {
                if (sib == status || sib == avatar || sib.tag == 0x574354) continue;
                CGSize z = sib.bounds.size;
                if (z.width >= 20 && z.width <= 44 && fabs(z.width - z.height) < 3 && sib.layer.cornerRadius >= z.width / 2 - 1.5 && ![sib isDescendantOfView:avatar]) { circle = sib; break; }
                [st2 addObject:sib];
            }
        }
        CGFloat pw = status.bounds.size.width, cw = circle ? circle.bounds.size.width : 0, gap = 8;
        CGFloat total = pw + (circle ? gap + cw : 0);
        if (circle) {
            LYHWPlace(circle, h, W / 2 - total / 2 + cw / 2, cardTop + 200);
            LYHWPlace(status, h, W / 2 + total / 2 - pw / 2, cardTop + 200);
        } else LYHWPlace(status, h, W / 2, cardTop + 200);
    }
    if (fabs(h.bounds.size.height - (cardTop + cardH)) > 0.5) {
        CGRect hf = h.frame; hf.size.height = cardTop + cardH; h.frame = hf; tv.tableHeaderView = h;
    }
}

static void LYHWRoundHeaderSearch(UIView *v, CGFloat W, CGFloat r, int depth) {
    if (depth > 8) return;
    for (UIView *sv in v.subviews) {
        CGSize z = sv.bounds.size;
        if (!sv.hidden && z.width >= W * 0.7 && z.height >= 28 && z.height <= 52 && ![sv isKindOfClass:[UILabel class]]) {
            BOOL filled = [sv isKindOfClass:[UITextField class]] || [sv isKindOfClass:[UIImageView class]] ||
                (sv.backgroundColor && CGColorGetAlpha(sv.backgroundColor.CGColor) > 0.05);
            if (filled) {
                sv.layer.cornerRadius = MIN(r, z.height / 2.0);
                if (@available(iOS 13.0, *)) sv.layer.cornerCurve = kCACornerCurveContinuous;
                sv.clipsToBounds = YES;
            }
        }
        LYHWRoundHeaderSearch(sv, W, r, depth + 1);
    }
}

%hook UITableView
- (void)layoutSubviews {
    %orig;
    if (LYHWCCfg().searchCornerEnabled) {
        NSInteger pk = LYHWPageKind(self);
        UIView *th = [(UITableView *)self tableHeaderView];
        if ((pk == 1 || pk == 2) && th) LYHWRoundHeaderSearch(th, ((UIView *)self).bounds.size.width, LYHWCCfg().searchCornerRadius, 0);
    }
    if (!LYHWAnyCardOn()) return;
    if (LYHWCCfg().myPageCornerEnabled && LYHWPageKind(self) == 3) {
        LYHWStyleMyHeader((UITableView *)self);
        UITableView *mtv = (UITableView *)self;
        mtv.alwaysBounceVertical = NO;
        {
            UIEdgeInsets ai = mtv.adjustedContentInset, ci = mtv.contentInset;
            CGFloat want = ci.bottom - ai.bottom;
            if (fabs(ci.bottom - want) > 0.5) { ci.bottom = want; mtv.contentInset = ci; }
        }
        {
            CGFloat hh = mtv.tableHeaderView.bounds.size.height + 20;
            for (UIView *sv in mtv.subviews) {
                if (sv.bounds.size.height <= 1.5 && sv.bounds.size.width >= mtv.bounds.size.width * 0.9 && sv.frame.origin.y < hh) sv.hidden = YES;
            }
            for (UIView *sv in mtv.tableHeaderView.subviews) {
                if (sv.bounds.size.height <= 1.5 && sv.bounds.size.width >= mtv.bounds.size.width * 0.9) sv.hidden = YES;
            }
        }
        if (mtv.tableFooterView && mtv.tableFooterView.bounds.size.height > 1) { UIView *f = [UIView new]; f.frame = CGRectMake(0, 0, 1, 0.01); mtv.tableFooterView = f; }
    }
    else if ((LYHWCCfg().profilePageCornerEnabled && LYHWPageKind(self) == 7) || (LYHWCCfg().groupInfoCornerEnabled && LYHWPageKind(self) == 9)) LYHWStyleInfoHeader((UITableView *)self);
    [objc_getAssociatedObject(self, @selector(LYHWGroupInfo)) removeAllObjects];
    for (UITableViewCell *cell in [(UITableView *)self visibleCells]) LYHWStyleCellCard(cell);
}
%end

static void LYHWClearTree(UIView *v) {
    v.backgroundColor = [UIColor clearColor];
    for (UIView *sv in v.subviews) if (![sv isKindOfClass:[UIImageView class]] && ![sv isKindOfClass:[UILabel class]]) LYHWClearTree(sv);
}
%hook ChatFoldCellView
- (void)layoutSubviews {
    %orig;
    if (LYHWCCfg().mainFrameCornerEnabled) LYHWClearTree((UIView *)self);
}
%end


static BOOL LYHWIsWhiteish(UIColor *c) {
    CGFloat w = 0, a = 0;
    if (!c) return YES;
    if ([c getWhite:&w alpha:&a]) return a < 0.05 || w > 0.985;
    CGFloat r, g, b;
    if ([c getRed:&r green:&g blue:&b alpha:&a]) return a < 0.05 || (r > 0.985 && g > 0.985 && b > 0.985);
    return NO;
}
%hook WCTimeLineCommentCellView
- (void)layoutSubviews {
    %orig;
    LYHWConfig *c = LYHWCCfg();
    if (!c.timelineCommentCornerEnabled) return;
    UIView *me = (UIView *)self;
    UIView *box = nil;
    CGFloat best = 0, W = me.bounds.size.width;
    NSMutableArray *st = [NSMutableArray arrayWithObject:me];
    while (st.count) {
        UIView *v = st.lastObject; [st removeLastObject];
        for (UIView *sv in v.subviews) {
            if ([sv isKindOfClass:[UILabel class]] || sv.hidden) continue;
            CGSize z = sv.bounds.size;
            BOOL filled = !LYHWIsWhiteish(sv.backgroundColor) || ([sv isKindOfClass:[UIImageView class]] && ((UIImageView *)sv).image);
            if (filled && z.width >= W * 0.6 && z.height >= 16 && z.width * z.height > best) { best = z.width * z.height; box = sv; }
            if (z.width >= W * 0.6) [st addObject:sv];
        }
    }
    if (!box && !LYHWIsWhiteish(me.backgroundColor)) box = me;
    if (!box) return;
    BOOL top = YES, bot = YES;
    if ([me respondsToSelector:@selector(needTopRoundCorner)]) top = ((BOOL (*)(id, SEL))objc_msgSend)(me, @selector(needTopRoundCorner));
    if ([me respondsToSelector:@selector(needBottomRoundCorner)]) bot = ((BOOL (*)(id, SEL))objc_msgSend)(me, @selector(needBottomRoundCorner));
    CACornerMask m = 0;
    if (top) m |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (bot) m |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    box.layer.cornerRadius = m ? c.timelineCommentCornerRadius : 0;
    box.layer.maskedCorners = m;
    box.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) box.layer.cornerCurve = kCACornerCurveContinuous;
}
%end


#pragma mark - 服务页（WCPayMainViewControllerV2）
static BOOL LYHWInService(UIView *v) {
    for (UIResponder *r = v; r; r = r.nextResponder)
        if ([r isKindOfClass:[UIViewController class]]) return [NSStringFromClass([r class]) isEqualToString:@"WCPayMainViewControllerV2"];
    return NO;
}
static void LYHWRoundCard(UIView *v, CGFloat r) {
    v.layer.cornerRadius = r;
    if (@available(iOS 13.0, *)) v.layer.cornerCurve = kCACornerCurveContinuous;
    v.layer.masksToBounds = YES;
}
%hook UICollectionView
- (void)layoutSubviews {
    %orig;
    LYHWConfig *c = LYHWCCfg();
    if (!c.servicePageCornerEnabled) return;
    UICollectionView *cv = (UICollectionView *)self;
    if (!LYHWInService(cv)) return;
    CGFloat W = cv.bounds.size.width, r = c.servicePageCornerRadius, m = 10;
    cv.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }];
    for (UIView *sv in cv.subviews) {
        if ([sv isKindOfClass:[UICollectionViewCell class]] || [sv isKindOfClass:[UIImageView class]]) continue;
        if (![sv isKindOfClass:[UICollectionReusableView class]]) continue;
        CGRect f = sv.frame;
        if (f.size.width >= W * 0.9 && f.size.height >= 60) {
            f.origin.x = m; f.size.width = W - m * 2; sv.frame = f;
            LYHWRoundCard(sv, r);
        }
    }
    UIViewController *vc = nil;
    for (UIResponder *x = cv; x; x = x.nextResponder) if ([x isKindOfClass:[UIViewController class]]) { vc = (UIViewController *)x; break; }
    @try {
        UIView *hv = [vc valueForKey:@"headerView"];
        if ([hv isKindOfClass:[UIView class]]) {
            UIView *target = hv;
            for (UIView *sv in hv.subviews) if (sv.bounds.size.width >= hv.bounds.size.width * 0.85 && sv.bounds.size.height >= 80) { target = sv; break; }
            LYHWRoundCard(target, r);
        }
    } @catch (__unused id e) {}
}
%end

#pragma mark - 朋友圈 赞/评论 浮层胶囊
%hook WCOperateFloatView
- (void)layoutSubviews {
    %orig;
    if (!LYHWCCfg().timelineCommentCornerEnabled) return;
    UIView *me = (UIView *)self;
    CGFloat h = me.bounds.size.height;
    if (h < 10) return;
    me.layer.cornerRadius = h / 2;
    if (@available(iOS 13.0, *)) me.layer.cornerCurve = kCACornerCurveContinuous;
    me.clipsToBounds = YES;
    for (UIView *sv in me.subviews) {
        if (sv.bounds.size.height >= h * 0.8 && sv.bounds.size.width >= me.bounds.size.width * 0.8) {
            sv.layer.cornerRadius = h / 2; sv.clipsToBounds = YES;
        }
    }
}
%end
