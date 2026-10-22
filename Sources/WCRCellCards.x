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
    NSMutableArray *all = [NSMutableArray arrayWithObject:cell];
    [all addObject:cell.contentView];
    for (UIView *host in all)
        for (UIView *v in host.subviews) {
            if (v.tag == 0x574352) continue;
            if (v.bounds.size.height <= 1.5 && v.bounds.size.width >= cell.bounds.size.width * 0.4) v.hidden = YES;
        }
}

static NSInteger WCRPageKind(UIView *v) { // 1主列表 2通讯录 3我 4发现 0其他
    for (UIResponder *r = v; r; r = r.nextResponder) {
        if (![r isKindOfClass:[UIViewController class]]) continue;
        NSString *n = NSStringFromClass([r class]);
        if ([n containsString:@"WCTimeLineViewController"]) return 5;
        if ([n containsString:@"FindFriend"]) return 4;
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
    if (kind == 5) {
        tv.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            return t.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }];
        tv.separatorStyle = UITableViewCellSeparatorStyleNone;
        WCRHideLines(cell);
        return;
    }
    if ((kind == 1 && !c.mainFrameCornerEnabled) || (kind == 2 && !c.homepageCornerEnabled) ||
        (kind == 3 && !c.myPageCornerEnabled) || (kind == 4 && !c.discoverPageCornerEnabled)) return;
    BOOL fancy = (kind != 4);
    CGFloat radius = fancy ? 22.0 : (c.globalCornerRadius > 0 ? c.globalCornerRadius : 24.0);
    CGFloat margin = fancy ? 9.0 : (c.globalCornerMargin > 0 ? c.globalCornerMargin : 18.0);
    NSInteger rows = [tv numberOfRowsInSection:ip.section];

    // 列表底色：浅灰，卡片为白
    UIColor *bg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1];
    }];
    tv.backgroundColor = bg;
    tv.separatorStyle = UITableViewCellSeparatorStyleNone;
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
    card.layer.cornerRadius = radius;
    card.layer.masksToBounds = !fancy;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    CACornerMask m = 0;
    if (ip.row == 0) m |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if (ip.row == rows - 1) m |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    card.layer.maskedCorners = m;
    BOOL single = (kind == 1);
    if (single) {
        card.frame = CGRectInset(card.frame, 0, 3);
        card.layer.cornerRadius = radius;
        card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner |
                                   kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else if (m == 0) card.layer.cornerRadius = 0;
    WCRHideLines(cell);
    if (fancy) {
        card.layer.masksToBounds = NO;   // 允许阴影；圆角由背景填充自带
        BOOL last = single || (ip.row == rows - 1);
        card.layer.shadowOpacity = (c.cardShadowEnabled && last) ? 0.14 : 0;
        card.layer.shadowRadius = 5;
        card.layer.shadowOffset = CGSizeMake(0, 3);
        card.layer.shadowColor = [UIColor blackColor].CGColor;
        card.layer.shadowPath = last ? [UIBezierPath bezierPathWithRoundedRect:card.bounds
            byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(radius, radius)].CGPath : NULL;
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
