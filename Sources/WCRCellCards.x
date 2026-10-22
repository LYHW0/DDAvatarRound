#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "WCRConfig.h"
#import "WCRCommon.h"

static inline WCRConfig *WCRCCfg(void) { return [WCRConfig shared]; }

static BOOL WCRAnyCardOn(void) {
    WCRConfig *c = WCRCCfg();
    return c.homepageCornerEnabled || c.mainFrameCornerEnabled ||
           c.discoverPageCornerEnabled || c.myPageCornerEnabled || c.settingPageCornerEnabled ||
           c.timelineCornerEnabled || c.forwardPickerCornerEnabled || c.profilePageCornerEnabled ||
           c.groupInfoCornerEnabled || c.servicePageCornerEnabled;
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
        if ([n isEqualToString:@"NewSettingViewController"]) return 6;
        if ([n isEqualToString:@"ContactInfoViewController"]) return 7;
        if ([n isEqualToString:@"ChatRoomInfoViewController"]) return 9;
        if ([n isEqualToString:@"SessionSelectController"] || [n isEqualToString:@"ContactSelectorViewController"] ||
            [n isEqualToString:@"MultiSelectContactsViewController"]) return 8;
        if ([n containsString:@"NewMainFrame"]) return 1;
        if ([n containsString:@"ContactsViewController"]) return 2;
        if ([n hasPrefix:@"MoreViewController"]) return 3;
    }
    return 0;
}

static void WCRRoundMedia(UIView *root, UIView *v) {
    for (UIView *sv in v.subviews) {
        NSString *cn = NSStringFromClass([sv class]);
        CGSize z = sv.bounds.size;
        BOOL media = [cn rangeOfString:@"WebImageView"].location != NSNotFound || [cn rangeOfString:@"SightView"].location != NSNotFound ||
                     [cn rangeOfString:@"MediaItem"].location != NSNotFound || [cn rangeOfString:@"ImageView"].location != NSNotFound || [sv isKindOfClass:[UIImageView class]];
        if (media && z.width >= 60 && z.height >= 60 && z.width < root.bounds.size.width - 40 && sv.layer.cornerRadius < 1) {
            sv.layer.cornerRadius = WCRCCfg().timelineMediaCornerRadius; sv.layer.masksToBounds = YES; sv.clipsToBounds = YES;
            if (@available(iOS 13.0, *)) sv.layer.cornerCurve = kCACornerCurveContinuous;
            continue;
        }
        if (media) continue;
        WCRRoundMedia(root, sv);
    }
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
    BOOL profileLike = (kind == 7 || kind == 9);
    if (kind == 9) { if (!c.groupInfoCornerEnabled) return; kind = 6; }
    if (kind == 7) { if (!c.profilePageCornerEnabled) return; kind = 6; }
    else if (kind == 6 && !c.settingPageCornerEnabled) return;
    BOOL picker = (kind == 8);
    if (picker) { if (!c.forwardPickerCornerEnabled) return; kind = 6; }
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
    if (picker) { radius = c.forwardPickerCornerRadius; margin = 14.0; fancy = YES; }
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
    UIColor *bg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1];
    }];
    if (picker) {
        bg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.0 alpha:1] : [UIColor whiteColor]; }];
    }
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
    card.backgroundColor = WCRCardFill();
    if (picker) card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor colorWithWhite:0.957 alpha:1]; }];
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
    BOOL single = NO;
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
    WCRHideLines(cell);
    if (timeline) {
        if (c.timelineMediaCornerEnabled) WCRRoundMedia(cell, cell);
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
    card.layer.shadowOpacity = 0;
    card.layer.shadowPath = NULL;
    {
        double strength = (c.cardShadowEnabled && !picker) ? MAX(0.0, MIN(1.0, c.cardShadowStrength)) : 0.0;
        NSMutableDictionary *pool = objc_getAssociatedObject(tv, @selector(WCRShadowPool));
        if (!pool) { pool = [NSMutableDictionary dictionary]; objc_setAssociatedObject(tv, @selector(WCRShadowPool), pool, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        if (strength <= 0) {
            for (UIView *v in pool.allValues) v.hidden = YES;
        } else if (isLastRow) {
            NSInteger fs = secFirst, frow = (secFirst == ip.section) ? fr : 0;
            CGRect firstR = [tv rectForRowAtIndexPath:[NSIndexPath indexPathForRow:frow inSection:fs]];
            CGFloat topInset = timeline ? 6 : 0;
            CGFloat x = cell.frame.origin.x + card.frame.origin.x;
            CGFloat top = firstR.origin.y + topInset;
            CGFloat bottom = cell.frame.origin.y + CGRectGetMaxY(card.frame);
            CGRect gr = CGRectMake(x, top, card.frame.size.width, MAX(1, bottom - top));
            UIView *sh = pool[@(secFirst)];
            if (!sh) {
                sh = [UIView new]; sh.userInteractionEnabled = NO; sh.backgroundColor = [UIColor clearColor];
                pool[@(secFirst)] = sh;
            }
            if (sh.superview != tv) {
                [sh removeFromSuperview];
                if (tv.backgroundView && tv.backgroundView.superview == tv) [tv insertSubview:sh aboveSubview:tv.backgroundView];
                else [tv insertSubview:sh atIndex:0];
            }
            sh.hidden = NO;
            sh.frame = gr;
            CGFloat rr = card.layer.cornerRadius > 0 ? card.layer.cornerRadius : radius;
            sh.layer.shadowColor = [UIColor blackColor].CGColor;
            sh.layer.shadowOpacity = (float)strength;
            sh.layer.shadowRadius = 9;
            sh.layer.shadowOffset = CGSizeMake(0, 5);
            sh.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:sh.bounds cornerRadius:rr].CGPath;
        }
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
    if (!h || h.bounds.size.width < 100 || h.bounds.size.height < 60) return;
    CGFloat W = h.bounds.size.width, H = h.bounds.size.height;
    UIView *card = [h viewWithTag:0x574355];
    if (!card) { card = [UIView new]; card.tag = 0x574355; card.userInteractionEnabled = NO; [h insertSubview:card atIndex:0]; }
    card.frame = CGRectMake(10, 4, W - 20, H - 12);
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor]; }];
    card.layer.cornerRadius = 24;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    double st = WCRCCfg().cardShadowEnabled ? WCRCCfg().cardShadowStrength : 0;
    card.layer.shadowColor = [UIColor blackColor].CGColor; card.layer.shadowOpacity = (float)st;
    card.layer.shadowRadius = 9; card.layer.shadowOffset = CGSizeMake(0, 5);
    card.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:card.bounds cornerRadius:24].CGPath;
    h.backgroundColor = [UIColor clearColor];
    stopW = W;
    WCRClearBg(h, card);
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
    WCRClearBg(h, nil);
    name.textAlignment = NSTextAlignmentCenter; wid.textAlignment = NSTextAlignmentCenter;
    WCRPlace(avatar, h, W / 2, cardTop + 62);
    WCRPlace(name, h, W / 2, cardTop + 128);
    WCRPlace(wid, h, W / 2, cardTop + 163);
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
            WCRPlace(circle, h, W / 2 - total / 2 + cw / 2, cardTop + 200);
            WCRPlace(status, h, W / 2 + total / 2 - pw / 2, cardTop + 200);
        } else WCRPlace(status, h, W / 2, cardTop + 200);
    }
    if (fabs(h.bounds.size.height - (cardTop + cardH)) > 0.5) {
        CGRect hf = h.frame; hf.size.height = cardTop + cardH; h.frame = hf; tv.tableHeaderView = h;
    }
}

%hook UITableView
- (void)layoutSubviews {
    %orig;
    if (!WCRAnyCardOn()) return;
    if (WCRCCfg().myPageCornerEnabled && WCRPageKind(self) == 3) {
        WCRStyleMyHeader((UITableView *)self);
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
    else if ((WCRCCfg().profilePageCornerEnabled && WCRPageKind(self) == 7) || (WCRCCfg().groupInfoCornerEnabled && WCRPageKind(self) == 9)) WCRStyleInfoHeader((UITableView *)self);
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


static BOOL WCRIsWhiteish(UIColor *c) {
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
    WCRConfig *c = WCRCCfg();
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
            BOOL filled = !WCRIsWhiteish(sv.backgroundColor) || ([sv isKindOfClass:[UIImageView class]] && ((UIImageView *)sv).image);
            if (filled && z.width >= W * 0.6 && z.height >= 16 && z.width * z.height > best) { best = z.width * z.height; box = sv; }
            if (z.width >= W * 0.6) [st addObject:sv];
        }
    }
    if (!box && !WCRIsWhiteish(me.backgroundColor)) box = me;
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
static BOOL WCRInService(UIView *v) {
    for (UIResponder *r = v; r; r = r.nextResponder)
        if ([r isKindOfClass:[UIViewController class]]) return [NSStringFromClass([r class]) isEqualToString:@"WCPayMainViewControllerV2"];
    return NO;
}
static void WCRRoundCard(UIView *v, CGFloat r) {
    v.layer.cornerRadius = r;
    if (@available(iOS 13.0, *)) v.layer.cornerCurve = kCACornerCurveContinuous;
    v.layer.masksToBounds = YES;
}
%hook UICollectionView
- (void)layoutSubviews {
    %orig;
    WCRConfig *c = WCRCCfg();
    if (!c.servicePageCornerEnabled) return;
    UICollectionView *cv = (UICollectionView *)self;
    if (!WCRInService(cv)) return;
    CGFloat W = cv.bounds.size.width, r = c.servicePageCornerRadius, m = 10;
    cv.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }];
    for (UIView *sv in cv.subviews) {
        if ([sv isKindOfClass:[UICollectionViewCell class]] || [sv isKindOfClass:[UIImageView class]]) continue;
        if (![sv isKindOfClass:[UICollectionReusableView class]]) continue;
        CGRect f = sv.frame;
        if (f.size.width >= W * 0.9 && f.size.height >= 60) {
            f.origin.x = m; f.size.width = W - m * 2; sv.frame = f;
            WCRRoundCard(sv, r);
        }
    }
    UIViewController *vc = nil;
    for (UIResponder *x = cv; x; x = x.nextResponder) if ([x isKindOfClass:[UIViewController class]]) { vc = (UIViewController *)x; break; }
    @try {
        UIView *hv = [vc valueForKey:@"headerView"];
        if ([hv isKindOfClass:[UIView class]]) {
            UIView *target = hv;
            for (UIView *sv in hv.subviews) if (sv.bounds.size.width >= hv.bounds.size.width * 0.85 && sv.bounds.size.height >= 80) { target = sv; break; }
            WCRRoundCard(target, r);
        }
    } @catch (__unused id e) {}
}
%end

#pragma mark - 转发选择器：最近转发卡片
%hook RecentForwardScrollView
- (void)layoutSubviews {
    %orig;
    WCRConfig *c = WCRCCfg();
    if (!c.forwardPickerCornerEnabled) return;
    UIView *me = (UIView *)self;
    me.backgroundColor = [UIColor clearColor];
    UIView *card = [me viewWithTag:0x574649];
    if (!card) { card = [UIView new]; card.tag = 0x574649; card.userInteractionEnabled = NO; [me insertSubview:card atIndex:0]; }
    card.frame = CGRectMake(14, 6, me.bounds.size.width - 28, me.bounds.size.height - 12);
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor colorWithWhite:0.957 alpha:1]; }];
    card.layer.cornerRadius = c.forwardPickerCornerRadius;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    for (UIView *sv in me.subviews) {
        if (sv == card) continue;
        if (sv.bounds.size.height <= 1.5) sv.hidden = YES;
        if ([sv isKindOfClass:[UIScrollView class]]) { sv.backgroundColor = [UIColor clearColor]; sv.layer.cornerRadius = 0; }
    }
}
%end
