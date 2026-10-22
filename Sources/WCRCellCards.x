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

static void WCRStyleCellCard(UITableViewCell *cell) {
    if (!cell) return;
    NSString *cls = NSStringFromClass([cell class]);
    if (WCRClassExcluded(cls)) return;

    WCRConfig *c = WCRCCfg();
    CGFloat radius = c.globalCornerRadius > 0 ? c.globalCornerRadius : 12.0;
    CGFloat margin = c.globalCornerMargin > 0 ? c.globalCornerMargin : 8.0;

    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];

    // 卡片背景穿在 cell 自己的 backgroundView 上，不改 contentView 的 frame，
    // 避免和微信内部的 Auto Layout 打架。
    UIView *card = cell.backgroundView;
    if (!card || card.tag != 0x574352) {
        card = [[UIView alloc] initWithFrame:cell.bounds];
        card.tag = 0x574352;
        card.userInteractionEnabled = NO;
        cell.backgroundView = card;
    }
    CGRect b = cell.bounds;
    card.frame = CGRectInset(b, margin, margin * 0.5);
    card.backgroundColor = WCRCardFill();
    card.layer.cornerRadius = radius;
    card.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;

    // 列表底色留出对比，否则白卡片贴白底看不出圆角。
    UIView *parent = cell.superview;
    if ([parent isKindOfClass:[UITableView class]]) {
        parent.backgroundColor = [UIColor systemGroupedBackgroundColor];
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
