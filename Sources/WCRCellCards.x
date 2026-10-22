#import <UIKit/UIKit.h>
#import "WCRConfig.h"
#import "WCRCommon.h"

static inline WCRConfig *WCRCCfg(void) { return [WCRConfig shared]; }

static BOOL WCRAnyCardOn(void) {
    WCRConfig *c = WCRCCfg();
    return c.homepageCornerEnabled || c.mainFrameCornerEnabled ||
           c.discoverPageCornerEnabled || c.myPageCornerEnabled;
}

static BOOL WCRClassExcluded(NSString *cls) {
    NSArray *bad = @[@"Input", @"Keyboard", @"SearchBar", @"Emoticon", @"Alert"];
    for (NSString *b in bad) {
        if ([cls rangeOfString:b options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}

static UIColor *WCRCardFill(void) {
    WCRConfig *c = WCRCCfg();
    UIColor *u = WCRColorForAppearance(c.globalCornerBackgroundColorLight,
                                       c.globalCornerBackgroundColorDark);
    if (!u) return [UIColor secondarySystemBackgroundColor];
    return u;
}

static BOOL WCRInChatPage(UIView *v) {
    UIResponder *r = v;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            NSString *n = NSStringFromClass([r class]);
            if ([n containsString:@"BaseMsgContent"] || [n containsString:@"ChatRoom"] ||
                [n containsString:@"MessageList"]) return YES;
        }
        r = r.nextResponder;
    }
    return NO;
}

static void WCRHideLines(UITableViewCell *cell) {
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

static NSInteger WCRPageKind(UIView *v) { // 1主列表 2通讯录 3我 4发现 0其他
    for (UIResponder *r = v; r; r = r.nextResponder) {
        if (![r isKindOfClass:[UIViewController class]]) continue;
        NSString *n = NSStringFromClass([r class]);
        if ([n containsString:@"WCTimeLineViewController"]) return 5;
        if ([n containsString:@"FindFriend"]) return 4;
        if ([n isEqualToString:@"NewSettingViewController"] || [n isEqualToString:@"ContactInfoViewController"]) return 6;
        if ([n containsString:@"NewMainFrame"]) return 1;
        if ([n containsString:@"ContactsViewController"]) return 2;
        if ([n hasPrefix:@"MoreViewController"]) return 3;
    }
    return 0;
}

static void WCRStyleCellCard(UITableViewCell *cell) {
    if (!cell) return;
    if (WCRClassExcluded(NSStringFromClass([cell class]))) return;
    UITableView *tv = nil;
    for (UIView *v = cell.superview; v; v = v.superview)
        if ([v isKindOfClass:[UITableView class]]) { tv = (UITableView *)v; break; }
    if (!tv || WCRInChatPage(tv)) return;
    NSIndexPath *ip = [tv indexPathForCell:cell];
    if (!ip) return;

    WCRConfig *c = WCRCCfg();
    NSInteger kind = WCRPageKind(tv);
    if (kind == 0) return;
    BOOL settingPage = (kind == 6);
    if (settingPage) { if (!c.settingPageCornerEnabled) return; kind = 4; }
    BOOL timeline = (kind == 5);
    if (timeline) kind = 1;  // 朋友圈改为和主页一样，每行独立卡片
    if ((kind == 1 && !c.mainFrameCornerEnabled) || (kind == 2 && !c.homepageCornerEnabled) ||
        (kind == 3 && !c.myPageCornerEnabled) || (kind == 4 && !settingPage && !c.discoverPageCornerEnabled)) return;
    BOOL fancy = (kind != 4);
        CGFloat radius = kind == 1 ? 22.0 : (kind == 3 ? (c.myPageCornerRadius > 0 ? c.myPageCornerRadius : 24.0) : fancy ? 24.0 : (c.globalCornerRadius > 0 ? c.globalCornerRadius : 28.0));
    CGFloat margin = kind == 1 ? 9.0 : (kind == 2 ? 10.0 : (kind == 3 ? (c.myPageCornerMargin > 0 ? c.myPageCornerMargin : 20.0) : fancy ? 20.0 : (c.globalCornerMargin > 0 ? c.globalCornerMargin : 18.0)));
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
    while (fr < lr && [tv rectForRowAtIndexPath:[NSIndexPath indexPathForRow:fr inSection:ip.section]].size.height <= 1.0) fr++;
    while (lr > fr && [tv rectForRowAtIndexPath:[NSIndexPath indexPathForRow:lr inSection:ip.section]].size.height <= 1.0) lr--;
    BOOL isFirstRow = (ip.section == secFirst && ip.row <= fr);
    BOOL isLastRow = (ip.section == secLast && ip.row >= lr);

    // 列表底色：浅灰，卡片为白
    UIColor *bg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1];
    }];
    tv.backgroundColor = bg;
    tv.separatorStyle = UITableViewCellSeparatorStyleNone;
    tv.sectionIndexBackgroundColor = [UIColor clearColor];
    tv.sectionIndexTrackingBackgroundColor = [UIColor clearColor];
    if (fancy) tv.clipsToBounds = NO;

    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    UIView *card = cell.backgroundView;
    if (!card || card.tag != 0x574352) {
        card = [UIView new];
        card.tag = 0x574352;
        card.userInteractionEnabled = NO;
        cell.backgroundView = card;
    }
    // 同组整块：上下不留缝，只有首尾行有圆角
    card.frame = CGRectMake(margin, 0, cell.bounds.size.width - margin * 2, cell.bounds.size.height);
    card.backgroundColor = WCRCardFill();
    if (kind == 1 && !timeline) {
        card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor colorWithWhite:0.975 alpha:1];
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
    BOOL single = timeline;
    if (single) {
        card.layer.cornerRadius = radius;
        card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner |
                                   kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
        CGRect f = card.frame;
        f.origin.y = 3;
        f.size.height = cell.bounds.size.height - 6;
        card.frame = f;
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
    WCRHideLines(cell);
    if (fancy) {
        card.layer.masksToBounds = NO;   // 允许阴影；圆角由背景填充自带
        BOOL last = single || isLastRow;
        card.layer.shadowOpacity = (c.cardShadowEnabled && last && kind == 1 && !timeline) ? 0.12 : 0;
        card.layer.shadowRadius = 5;
        card.layer.shadowOffset = CGSizeMake(0, 3);
        card.layer.shadowColor = [UIColor blackColor].CGColor;
        card.layer.shadowPath = last ? [UIBezierPath bezierPathWithRoundedRect:card.bounds
            byRoundingCorners:(single ? UIRectCornerAllCorners : (UIRectCornerBottomLeft | UIRectCornerBottomRight)) cornerRadii:CGSizeMake(radius, radius)].CGPath : NULL;
    }
}

%hook UITableViewCell
- (void)layoutSubviews {
    %orig;
    if (!WCRAnyCardOn()) return;
    WCRStyleCellCard((UITableViewCell *)self);
}
%end

%hook UICollectionViewCell
- (void)layoutSubviews {
    %orig;
    if (!WCRAnyCardOn()) return;
    UICollectionViewCell *cell = (UICollectionViewCell *)self;
    NSString *cls = NSStringFromClass([cell class]);
    if (WCRClassExcluded(cls)) return;
    WCRConfig *c = WCRCCfg();
    CGFloat radius = c.globalCornerRadius > 0 ? c.globalCornerRadius : 12.0;
    cell.contentView.layer.cornerRadius = radius;
    cell.contentView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
}
%end

static void WCRPlace(UIView *v, UIView *h, CGFloat tx, CGFloat ty) {
    v.transform = CGAffineTransformIdentity;
    CGRect f = [v.superview convertRect:v.frame toView:h];
    v.transform = CGAffineTransformMakeTranslation(tx - CGRectGetMidX(f), ty - CGRectGetMidY(f));
}

static CGFloat stopW = 0;
static void WCRClearBg(UIView *v, UIView *stop) {
    for (UIView *sv in v.subviews) {
        if (sv == stop || sv.tag == 0x574354 || sv.tag == 0x574355) continue;
        CGFloat sw = sv.bounds.size.width, sh = sv.bounds.size.height;
        if (sw >= stopW * 0.85 && sh >= 100) {
            sv.backgroundColor = [UIColor clearColor];
            sv.layer.backgroundColor = nil; sv.layer.cornerRadius = 0;
            if (([sv isKindOfClass:[UIImageView class]] || [sv isKindOfClass:[UIVisualEffectView class]]) && sv.subviews.count == 0) { sv.hidden = YES; continue; }
        }
        if ([sv isKindOfClass:[UILabel class]] || [sv isKindOfClass:[UIImageView class]] || [sv isKindOfClass:[UIButton class]]) continue;
        if (sv.subviews.count > 0 && sv.bounds.size.height > 40) sv.backgroundColor = [UIColor clearColor];
        WCRClearBg(sv, stop);
    }
}

static void WCRFlatWhite(UIView *v, UIColor *c, CGFloat W) {
    for (UIView *sv in v.subviews) {
        if ([sv isKindOfClass:[UILabel class]] || [sv isKindOfClass:[UIButton class]]) continue;
        if (sv.bounds.size.width >= W * 0.85 && sv.bounds.size.height >= 60) {
            sv.backgroundColor = c; sv.layer.cornerRadius = 0; sv.layer.backgroundColor = c.CGColor;
        }
        WCRFlatWhite(sv, c, W);
    }
}
static void WCRStyleInfoHeader(UITableView *tv) {
    UIView *h = tv.tableHeaderView;
    if (!h || h.bounds.size.width < 100) return;
    UIColor *w = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor]; }];
    h.backgroundColor = w; h.layer.cornerRadius = 0;
    WCRFlatWhite(h, w, h.bounds.size.width);
}

static void WCRStyleMyHeader(UITableView *tv) {
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
    CGFloat cardTop = 0, cardH = 217, mx = 8;
    UIView *card = [h viewWithTag:0x574354];
    if (!card) { card = [UIView new]; card.tag = 0x574354; card.userInteractionEnabled = NO; [h insertSubview:card atIndex:0]; }
    card.frame = CGRectMake(mx, cardTop, W - mx * 2, cardH);
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor]; }];
    card.layer.cornerRadius = 24;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    h.backgroundColor = [UIColor clearColor];
    stopW = W;
    WCRClearBg(h, nil);
    name.textAlignment = NSTextAlignmentCenter; wid.textAlignment = NSTextAlignmentCenter;
    WCRPlace(avatar, h, W / 2, cardTop + 49);
    WCRPlace(name, h, W / 2, cardTop + 114);
    WCRPlace(wid, h, W / 2, cardTop + 150);
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
            WCRPlace(circle, h, W / 2 - total / 2 + cw / 2, cardTop + 188);
            WCRPlace(status, h, W / 2 + total / 2 - pw / 2, cardTop + 188);
        } else WCRPlace(status, h, W / 2, cardTop + 188);
    }
    if (fabs(h.bounds.size.height - (cardTop + cardH + 12)) > 0.5) {
        CGRect hf = h.frame; hf.size.height = cardTop + cardH + 12; h.frame = hf; tv.tableHeaderView = h;
    }
}

%hook UITableView
- (void)layoutSubviews {
    %orig;
    if (!WCRAnyCardOn()) return;
    if (WCRCCfg().myPageCornerEnabled && WCRPageKind(self) == 3) WCRStyleMyHeader((UITableView *)self);
    else if (WCRPageKind(self) == 6 && [NSStringFromClass([[(UITableView *)self nextResponder] class]) length] && ^BOOL{ for (UIResponder *r = (UIView *)self; r; r = r.nextResponder) if ([NSStringFromClass([r class]) isEqualToString:@"ContactInfoViewController"]) return YES; return NO; }()) WCRStyleInfoHeader((UITableView *)self);
    for (UITableViewCell *cell in [(UITableView *)self visibleCells]) WCRStyleCellCard(cell);
}
%end

static void WCRClearTree(UIView *v) {
    v.backgroundColor = [UIColor clearColor];
    for (UIView *sv in v.subviews) if (![sv isKindOfClass:[UIImageView class]] && ![sv isKindOfClass:[UILabel class]]) WCRClearTree(sv);
}
%hook ChatFoldCellView
- (void)layoutSubviews {
    %orig;
    if (WCRCCfg().mainFrameCornerEnabled) WCRClearTree((UIView *)self);
}
%end
