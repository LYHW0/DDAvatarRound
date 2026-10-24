#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "LYHWConfig.h"
#import "LYHWCommon.h"

static inline LYHWConfig *LYHWCCfg(void) { return [LYHWConfig shared]; }

// 最后一行的阴影挂在 cell.layer 上。微信长按时会先后调用 highlighted/selected，
// 两个状态存在短暂交错；用独立按压标记把整段手势锁住，避免阴影在中途恢复后跟着 cell 动。
static const void *kLYHWPressActiveKey = &kLYHWPressActiveKey;
static BOOL LYHWPressActive(UITableViewCell *cell) {
    return [objc_getAssociatedObject(cell, kLYHWPressActiveKey) boolValue];
}
static void LYHWSetPressActive(UITableViewCell *cell, BOOL active) {
    objc_setAssociatedObject(cell, kLYHWPressActiveKey, @(active), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIColor *LYHWCachedPalette0(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1];
    }]; });
    return color;
}
static UIColor *LYHWCachedPalette1(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : UIColor.whiteColor;
    }]; });
    return color;
}
static UIColor *LYHWCachedPalette2(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor];
        }]; });
    return color;
}
static UIColor *LYHWCachedPalette3(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
                return (t.userInterfaceStyle == UIUserInterfaceStyleDark
                    ? [UIColor colorWithWhite:0.22 alpha:1] : [UIColor colorWithWhite:0.88 alpha:1]);
            }]; });
    return color;
}
static UIColor *LYHWCachedPalette4(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor]; }]; });
    return color;
}
static UIColor *LYHWCachedPalette5(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor whiteColor]; }]; });
    return color;
}
static UIColor *LYHWCachedPalette6(void) {
    static UIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ color = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.05 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1]; }]; });
    return color;
}

// Local idempotent setter: never hook UIView globally. Compare UIColor objects,
// not resolved CGColors, so dynamic light/dark behavior remains intact.
static void LYHWSetBackgroundIfChanged(UIView *view, UIColor *color) {
    if (!view) return;
    UIColor *old = view.backgroundColor;
    if (old == color || [old isEqual:color]) return;
    view.backgroundColor = color;
}

static UIColor *LYHWListGray(void) {
    return LYHWCachedPalette0();
}


static BOOL LYHWAnyCardOn(void) {
    LYHWConfig *c = LYHWCCfg();
    return c.homepageCornerEnabled || c.mainFrameCornerEnabled ||
           c.discoverPageCornerEnabled || c.myPageCornerEnabled || c.settingPageCornerEnabled ||
           c.timelineCornerEnabled || c.profilePageCornerEnabled || c.chatDetailCornerEnabled ||
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
    static NSString *lastLight, *lastDark;
    static UIColor *u;
    NSString *light = c.globalCornerBackgroundColorLight ?: @"";
    NSString *dark = c.globalCornerBackgroundColorDark ?: @"";
    if (!u || ![lastLight isEqualToString:light] || ![lastDark isEqualToString:dark]) {
        lastLight = [light copy]; lastDark = [dark copy];
        u = LYHWColorForAppearance(lastLight, lastDark);
    }
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

static void LYHWHideLinesIn(UIView *root, CGFloat minW, int depth) {
    if (depth > 3 || !root) return;
    for (UIView *v in [root.subviews copy]) {
        if (v.tag == 0x574352 || v.tag == 0x574353 || v.tag == 0x574357) continue;
        if ([v isKindOfClass:[UILabel class]] || [v isKindOfClass:[UIButton class]]) continue;
        // 只按尺寸判断：极薄且够宽的横条一律当分隔线隐藏（不依赖类名）
        CGFloat h = v.bounds.size.height, w = v.bounds.size.width;
        if (h > 0.05 && h <= 1.5 && w >= minW) { v.hidden = YES; continue; }
        LYHWHideLinesIn(v, minW, depth + 1);
    }
    // 有的分隔线是直接画在图层上的
    for (CALayer *l in [root.layer.sublayers copy]) {
        if (l.frame.size.height > 0.05 && l.frame.size.height <= 1.5 && l.frame.size.width >= minW) l.hidden = YES;
    }
}

static void LYHWHideLines(UITableViewCell *cell) {
    CGFloat minW = cell.bounds.size.width * 0.4;
    LYHWHideLinesIn(cell, minW, 0);
    LYHWHideLinesIn(cell.contentView, minW, 0);
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
        if (media && z.width >= 60 && z.height >= 60 && z.width < root.bounds.size.width - 40 && (sv.layer.cornerRadius < 1 || !sv.layer.masksToBounds)) {
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

// 卡片视图：frame 锁定。
// 转储证实：返回转场里 UIKit 会把 cell.backgroundView 重设成 cell 的 bounds（{0,0,393,56} 通栏），
// 稳定后才被我们改回 {10,0,373,56}，中间那几帧就是直角白条。
// 锁定后，任何人对 frame/bounds/center 的修改都会被纠正成我们要的矩形。
@interface LYHWCardView : UIView
@property (nonatomic, assign) CGRect lockedFrame;
@property (nonatomic, assign) BOOL locked;
@end
@implementation LYHWCardView
- (void)setFrame:(CGRect)f {
    [super setFrame:self.locked ? self.lockedFrame : f];
}
- (void)setBounds:(CGRect)b {
    if (self.locked) b = CGRectMake(0, 0, self.lockedFrame.size.width, self.lockedFrame.size.height);
    [super setBounds:b];
}
- (void)setCenter:(CGPoint)c {
    if (self.locked) c = CGPointMake(CGRectGetMidX(self.lockedFrame), CGRectGetMidY(self.lockedFrame));
    [super setCenter:c];
}
@end
static void LYHWSetCardFrame(UIView *card, CGRect r) {
    if ([card isKindOfClass:[LYHWCardView class]]) {
        LYHWCardView *cv = (LYHWCardView *)card;
        cv.lockedFrame = r; cv.locked = YES;
    }
    card.frame = r;
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
    // 遮罩路径必须在 contentView 自己的坐标系里算：转场/左滑时 contentView 相对 cell 有偏移，
    // 按 cell 坐标算会让裁剪错位，露出一层比卡片更宽的白色内容层（截图里卡片左侧多出的外圈）。
    CGRect r = [cell.contentView convertRect:card.frame fromView:card.superview];
    if (r.size.width < 1 || r.size.height < 1) { host.mask = nil; return; }
    LYHWSetBackgroundIfChanged(cell.contentView, [UIColor clearColor]);
    cell.contentView.layer.backgroundColor = [UIColor clearColor].CGColor;
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

// ===== 板块阴影（重写版）=====
// 不再使用 CALayer 的 shadowOpacity/shadowPath/shadowRadius/shadowOffset：
// 这些属性在 WeChat 返回转场的某一帧会被复位成默认值（上偏、发硬），表现为整块阴影闪一下。
// 现在改为：用 CoreGraphics 预先渲染一张「圆角卡片底部柔和投影」的九宫格图片，
// 直接作为宿主图层的 contents 显示。图片本身就是阴影，没有可被复位的阴影参数，也不会出现
// ─── 卡片阴影（重构版）─────────────────────────────────────────────
// 目标：贴着卡片下沿的柔和投影，边缘完全融开，没有第二层轮廓线。
// 做法：不再预渲染九宫格图，直接用两层 CALayer 阴影叠出「接触 + 环境」：
//   · 接触层：偏移小、模糊小，给出卡片与背景之间的分离感；
//   · 环境层：偏移大、模糊大、透明度低，负责整体漂浮感。
// 两层都用 shadowPath 精确贴合卡片圆角，所以圆角处不会出现方角或双层弧线。

static UIBezierPath *LYHWCardPath(CGRect r, CGFloat rad, CACornerMask cm) {
    if (rad < 0.5 || cm == 0) return [UIBezierPath bezierPathWithRect:r];
    UIRectCorner uc = 0;
    if (cm & kCALayerMinXMinYCorner) uc |= UIRectCornerTopLeft;
    if (cm & kCALayerMaxXMinYCorner) uc |= UIRectCornerTopRight;
    if (cm & kCALayerMinXMaxYCorner) uc |= UIRectCornerBottomLeft;
    if (cm & kCALayerMaxXMaxYCorner) uc |= UIRectCornerBottomRight;
    return [UIBezierPath bezierPathWithRoundedRect:r byRoundingCorners:uc cornerRadii:CGSizeMake(rad, rad)];
}

// 阴影只挂在 cell 自己的图层上，不额外加视图：
// 少一层视图就少一次 frame 被 UIKit 重置的机会，转场/左滑都不会跳。
// 下沉式阴影路径：比卡片左右各内收、顶部下移，只让阴影从底边和底部圆角透出来。
// 侧面不会出现一整条暗边，也不会把卡片周围的背景整体染深。
static void LYHWSetSinkShadow(CALayer *L, CGRect cardFrame, CGFloat rad, CACornerMask cm, double st) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (st <= 0.001 || cardFrame.size.width < 1 || cardFrame.size.height < 1) {
        L.shadowOpacity = 0;
        L.shadowPath = NULL;
        [CATransaction commit];
        return;
    }
    CGFloat dx = 7.0;
    CGFloat dy = MIN(cardFrame.size.height * 0.45, 14.0);
    CGRect r = cardFrame;
    r.origin.x += dx; r.size.width -= dx * 2;
    r.origin.y += dy; r.size.height -= dy;
    if (r.size.width < 1 || r.size.height < 1) r = cardFrame;
    UIBezierPath *path = LYHWCardPath(r, MAX(0, rad - 2), cm | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner);
    L.masksToBounds = NO;
    L.shadowColor = [UIColor blackColor].CGColor;
    L.shadowOpacity = (float)MIN(1.0, st * 1.4);
    L.shadowRadius = 9.0;
    L.shadowOffset = CGSizeMake(0, 6);
    L.shadowPath = path.CGPath;
    [CATransaction commit];
}

static void LYHWApplyCardShadow(UITableViewCell *cell, UIView *card, LYHWConfig *c, BOOL isBlockBottom) {
    if (!cell || !card) return;
    double st = c.cardShadowEnabled ? MAX(0.0, MIN(1.0, c.cardShadowStrength)) : 0.0;
    BOOL on = (st > 0.001) && isBlockBottom && !LYHWPressActive(cell) && !LYHWCellIsSwiped(cell) && !cell.highlighted && !cell.selected;
    LYHWSetSinkShadow(cell.layer, card.frame, card.layer.cornerRadius, card.layer.maskedCorners, on ? st : 0);
}

// 兼容旧调用点
static void LYHWHideShadowHost(UITableViewCell *cell) {
    if (!cell) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    cell.layer.shadowOpacity = 0;
    cell.layer.shadowPath = NULL;
    [CATransaction commit];
}

// 左滑按钮条（原生 UISwipeActionPullView / 微信自绘的 Swipe / Pull 容器）：
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

static void LYHWClearNearBlack(UIView *v) {
    if (!v) return;
    UIColor *bgc = v.backgroundColor;
    CGFloat w = 0, a = 1;
    if (bgc && [bgc getWhite:&w alpha:&a] && a > 0.02 && w < 0.35) {
        LYHWSetBackgroundIfChanged(v, [UIColor clearColor]);
        v.layer.backgroundColor = nil;
    }
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

    LYHWClearNearBlack(v);
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
            LYHWClearNearBlack(v);        // 容器若是近黑底，左滑时会从卡片边上漏出来
            LYHWScanSwipeViews(v, contentView, left, right, rad, cm, depth + 1);
            continue;
        }
        if (LYHWIsSwipeHostView(v)) { LYHWApplySwipeGeometry(v, left, right, rad, cm); continue; }
        LYHWScanSwipeViews(v, contentView, left, right, rad, cm, depth + 1);
    }
}

// 兜底：cell 里除内容层以外的任何兄弟视图，只要带投影就清掉。
//   左滑按钮层在 contentView 之上，它的投影会直接压在白卡上变成一条黑边。
//   这里不猜类名，凡是「盖在卡片上又带投影」的一律清掉（我们自己的阴影宿主 0x574357 除外）。
static void LYHWSweepSiblingShadows(UITableViewCell *cell) {
    if (!cell) return;
    for (UIView *v in [cell.subviews copy]) {
        if (v == cell.contentView || v == cell.backgroundView || v == cell.selectedBackgroundView) continue;
        if (v.tag == 0x574352 || v.tag == 0x574353 || v.tag == 0x574357) continue;
        if ([cell.contentView isDescendantOfView:v]) continue;   // 包着内容层的容器不动
        CALayer *l = v.layer;
        if (l.shadowOpacity > 0.001f || l.shadowPath) LYHWKillShadow(v);
    }
}

// ===== 微信自绘左滑（实测转储）=====
// cell 直接子视图：ColorGradientView(32x72，按钮左侧的黑色渐变) + 普通 UIView(装 MenuButton，右缘=屏幕边缘)。
// 类名里没有 Swipe/Pull，所以按「含 MenuButton 子视图」「类名含 Gradient」识别。
static BOOL LYHWIsMenuHost(UIView *v) {
    for (UIView *sv in v.subviews) {
        if ([NSStringFromClass([sv class]) rangeOfString:@"MenuButton"].location != NSNotFound) return YES;
    }
    return NO;
}

static UIRectCorner LYHWRectCornerFromMask(CACornerMask m) {
    UIRectCorner r = 0;
    if (m & kCALayerMinXMinYCorner) r |= UIRectCornerTopLeft;
    if (m & kCALayerMaxXMinYCorner) r |= UIRectCornerTopRight;
    if (m & kCALayerMinXMaxYCorner) r |= UIRectCornerBottomLeft;
    if (m & kCALayerMaxXMaxYCorner) r |= UIRectCornerBottomRight;
    return r;
}

static void LYHWClipMenuHost(UIView *host, UIView *cell, UIView *card) {
    CGRect cr = [cell convertRect:card.frame toView:host];     // 卡片在按钮容器坐标系里的位置
    CAShapeLayer *m = nil;
    if ([host.layer.mask isKindOfClass:[CAShapeLayer class]] &&
        [host.layer.mask.name isEqualToString:@"LYHWMenuMask"]) m = (CAShapeLayer *)host.layer.mask;
    if (!m) { m = [CAShapeLayer layer]; m.name = @"LYHWMenuMask"; }
    CGFloat rad = card.layer.cornerRadius;
    UIRectCorner rc = LYHWRectCornerFromMask(card.layer.maskedCorners);
    UIBezierPath *path = rad > 0.5
        ? [UIBezierPath bezierPathWithRoundedRect:cr byRoundingCorners:rc cornerRadii:CGSizeMake(rad, rad)]
        : [UIBezierPath bezierPathWithRect:cr];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    m.frame = host.bounds;
    m.path = path.CGPath;
    host.layer.mask = m;
    [CATransaction commit];
}

static BOOL LYHWTuneWeChatSwipe(UITableViewCell *cell, UIView *card) {
    if (!cell || !card) return NO;
    BOOL found = NO;
    for (UIView *v in [cell.subviews copy]) {
        if (v == cell.contentView || v == card) continue;
        if (v.tag == 0x574352 || v.tag == 0x574353 || v.tag == 0x574357) continue;
        NSString *cn = NSStringFromClass([v class]);
        if ([cn rangeOfString:@"Gradient" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            v.hidden = YES; v.alpha = 0; LYHWKillShadow(v); found = YES;      // 黑色渐变块
            continue;
        }
        if (LYHWIsMenuHost(v)) { LYHWClipMenuHost(v, cell, card); found = YES; }
    }
    return found;
}

@interface LYHWSwipeLink : NSObject
@property (nonatomic, weak) UITableViewCell *cell;
@property (nonatomic, weak) UIView *card;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) NSInteger idle;
@end
@implementation LYHWSwipeLink
- (void)tick:(CADisplayLink *)l {
    UITableViewCell *c = self.cell; UIView *card = self.card;
    if (!c || !card || !c.window) { [self stop]; return; }
    LYHWTuneWeChatSwipe(c, card);
    BOOL moved = fabs(c.contentView.frame.origin.x) > 0.5 || fabs(c.contentView.transform.tx) > 0.5;
    if (moved) self.idle = 0; else if (++self.idle > 30) [self stop];
}
- (void)stop { [self.link invalidate]; self.link = nil; if (self.cell) objc_setAssociatedObject(self.cell, @selector(tick:), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

static void LYHWStartSwipeLink(UITableViewCell *cell, UIView *card) {
    if (!cell || !card) return;
    if (objc_getAssociatedObject(cell, @selector(tick:))) return;
    LYHWSwipeLink *o = [LYHWSwipeLink new];
    o.cell = cell; o.card = card;
    o.link = [CADisplayLink displayLinkWithTarget:o selector:@selector(tick:)];
    [o.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    objc_setAssociatedObject(cell, @selector(tick:), o, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void LYHWConstrainSwipeViews(UITableViewCell *cell, UIView *card) {
    if (!cell || !card) return;
    CGRect cr = card.frame;
    if (cr.size.width < 1 || cr.size.height < 1) return;
    LYHWScanSwipeViews(cell, cell.contentView,
                       CGRectGetMinX(cr), CGRectGetMaxX(cr),
                       card.layer.cornerRadius, card.layer.maskedCorners, 0);
    LYHWSweepSiblingShadows(cell);
    if (LYHWTuneWeChatSwipe(cell, card)) LYHWStartSwipeLink(cell, card);
}

// 左滑按钮层是「开始滑动那一刻」才建出来的，cell 的 layoutSubviews 不一定再走一遍，
// 所以滑动中补几次重扫（同一段滑动只排一次，靠时间戳节流）。
static void LYHWScheduleSwipeRescan(UITableViewCell *cell, UIView *card) {
    if (!cell || !card) return;
    NSNumber *last = objc_getAssociatedObject(cell, @selector(LYHWScheduleSwipeRescan));
    NSTimeInterval now = CACurrentMediaTime();
    if (last && now - last.doubleValue < 0.4) return;
    objc_setAssociatedObject(cell, @selector(LYHWScheduleSwipeRescan), @(now),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (NSNumber *d in @[@0.04, @0.18, @0.40]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            LYHWConstrainSwipeViews(cell, card);
        });
    }
}

// ─────────────────────────────────────────────────────────────
// 群聊资料页：按全局圆角插件的 ZiLiaoSheZhi 模块重建
//
// 原模块的可确认行为：
//   1. 仅限 ChatRoomInfoViewController 的 UITableViewCell；
//   2. cell/contentView/表格背景清透明，去掉原生分隔线；
//   3. 按 section 首行/末行/单行插入 tag=0x45e0 的白色卡片，
//      用 CAShapeLayer mask 只圆应圆的角；
//   4. NewChatRoomMemberContainView 出现时，清理 WCTableView 的白底。
// 原插件的 getYinHangKaImageStyle 函数体没有随反编译结果提供，
// 因此半径/留白接入本插件自己的 groupInfoCorner* 配置。
// ─────────────────────────────────────────────────────────────
static UIViewController *LYHWOwnerViewController(UIView *v) {
    for (UIResponder *r = v; r; r = r.nextResponder)
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
    return nil;
}

static UITableView *LYHWAncestorTable(UIView *v) {
    for (UIView *p = v; p; p = p.superview)
        if ([p isKindOfClass:[UITableView class]]) return (UITableView *)p;
    return nil;
}

static BOOL LYHWIsGroupInfoTable(UITableView *tv) {
    if (!tv) return NO;
    UIViewController *vc = LYHWOwnerViewController(tv);
    return [vc isKindOfClass:NSClassFromString(@"ChatRoomInfoViewController")];
}

static BOOL LYHWIsGroupRoomInfoTable(UITableView *tv) {
    if (!LYHWIsGroupInfoTable(tv)) return NO;
    UIViewController *vc = LYHWOwnerViewController(tv);
    @try {
        id contact = [vc valueForKey:@"m_chatRoomContact"];
        NSString *userName = [contact valueForKey:@"userName"];
        if ([userName isKindOfClass:[NSString class]] && userName.length)
            return [userName hasSuffix:@"@chatroom"];
    } @catch (__unused NSException *e) {}
    // 若 dump 上的联系人标识不可读，不根据人数猜测；默认当单聊详情，
    // 避免把单聊误套成群聊页的启发式网格规则。
    return NO;
}

static BOOL LYHWChatInfoStyleEnabled(UITableView *tv) {
    if (LYHWIsGroupRoomInfoTable(tv)) return LYHWCCfg().groupInfoCornerEnabled;
    return LYHWCCfg().chatDetailCornerEnabled;
}

static void LYHWClearGroupInfoSurface(UITableView *tv) {
    if (!tv || !LYHWIsGroupInfoTable(tv)) return;
    LYHWSetBackgroundIfChanged(tv, [UIColor clearColor]);
    tv.layer.backgroundColor = nil;
    tv.backgroundView = nil;
    tv.separatorStyle = UITableViewCellSeparatorStyleNone;
    UIView *host = tv.superview;
    if (host && ![host isKindOfClass:[UITableViewCell class]]) LYHWSetBackgroundIfChanged(host, LYHWListGray());

    // 对应原模块在 WCTableView 上清理整宽底板；不触碰文字、头像和按钮。
    for (UIView *v in [tv.subviews copy]) {
        if ([v isKindOfClass:[UITableViewCell class]] || v == tv.tableHeaderView ||
            [v isKindOfClass:[UILabel class]] || [v isKindOfClass:[UIImageView class]] ||
            [v isKindOfClass:[UIButton class]]) continue;
        CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
        if (w >= tv.bounds.size.width * 0.82 && h > 4) {
            LYHWSetBackgroundIfChanged(v, [UIColor clearColor]);
            v.layer.backgroundColor = nil;
        }
        if (h <= 1.5 && w >= tv.bounds.size.width * 0.4) v.hidden = YES;
    }
}

static void LYHWClearGroupInfoContent(UIView *root, int depth) {
    if (!root || depth > 5) return;
    for (UIView *v in [root.subviews copy]) {
        NSString *cn = NSStringFromClass([v class]);
        if ([cn rangeOfString:@"Separator" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            (v.bounds.size.height <= 1.5 && v.bounds.size.width >= root.bounds.size.width * 0.4)) {
            v.hidden = YES;
            continue;
        }
        // 与原模块一样清掉 contentView 内部的底色，但保留图文控件自身。
        if (![v isKindOfClass:[UILabel class]] && ![v isKindOfClass:[UIImageView class]] &&
            ![v isKindOfClass:[UIButton class]]) {
            LYHWSetBackgroundIfChanged(v, [UIColor clearColor]);
            v.layer.backgroundColor = nil;
        }
        LYHWClearGroupInfoContent(v, depth + 1);
    }
}

// 以布局几何识别连续卡片：跨 section 但无实际空隙也算同一块，
// 群成员的多行网格/“更多群成员”因此共用首尾圆角。
static NSIndexPath *LYHWGroupAdjacent(UITableView *tv, NSIndexPath *ip, BOOL before) {
    NSInteger s = ip.section, r = ip.row + (before ? -1 : 1);
    for (NSInteger guard = 0; guard < 512; guard++) {
        if (s < 0 || s >= tv.numberOfSections) return nil;
        NSInteger count = [tv numberOfRowsInSection:s];
        if (r < 0) { s--; if (s < 0) return nil; r = [tv numberOfRowsInSection:s] - 1; continue; }
        if (r >= count) { s++; r = 0; continue; }
        NSIndexPath *candidate = [NSIndexPath indexPathForRow:r inSection:s];
        CGRect other = [tv rectForRowAtIndexPath:candidate];
        if (other.size.height > 1.0) {
            CGRect here = [tv rectForRowAtIndexPath:ip];
            CGFloat gap = before ? CGRectGetMinY(here) - CGRectGetMaxY(other)
                                 : CGRectGetMinY(other) - CGRectGetMaxY(here);
            return gap >= -1.0 && gap <= 1.5 ? candidate : nil;
        }
        r += before ? -1 : 1;
    }
    return nil;
}

static CGRect LYHWGroupBlockRect(UITableView *tv, NSIndexPath *ip) {
    CGRect block = [tv rectForRowAtIndexPath:ip];
    for (NSNumber *direction in @[@YES, @NO]) {
        NSIndexPath *cursor = ip;
        for (NSInteger count = 0; count < 512; count++) {
            NSIndexPath *next = LYHWGroupAdjacent(tv, cursor, direction.boolValue);
            if (!next) break;
            block = CGRectUnion(block, [tv rectForRowAtIndexPath:next]); cursor = next;
        }
    }
    return block;
}

static void LYHWStyleGroupInfoCell(UITableViewCell *cell) {
    UITableView *tv = LYHWAncestorTable(cell);
    if (!cell || !LYHWIsGroupInfoTable(tv)) return;
    LYHWConfig *c = LYHWCCfg();
    BOOL isGroup = LYHWIsGroupRoomInfoTable(tv);
    CGFloat configuredRadius = isGroup ? c.groupInfoCornerRadius : c.chatDetailCornerRadius;
    CGFloat configuredMargin = isGroup ? c.groupInfoCornerMargin : c.chatDetailCornerMargin;
    UIView *existing = [cell viewWithTag:0x45e0];
    if (!LYHWChatInfoStyleEnabled(tv)) {
        [existing removeFromSuperview];
        if ([cell.contentView.layer.mask.name isEqualToString:@"LYHWGroupClipMask"]) cell.contentView.layer.mask = nil;
        if (cell.selectedBackgroundView.tag == 0x45e1) cell.selectedBackgroundView = nil;
        return;
    }
    NSIndexPath *ip = [tv indexPathForCell:cell];
    if (!ip || cell.bounds.size.width < 1 || cell.bounds.size.height < 1) return;

    LYHWClearGroupInfoSurface(tv);
    // 只清旧路径，复用本版本卡片，避免每次 layout 移除重建。
    for (UIView *v in [cell.subviews copy])
        if (v.tag == 0x574352 || v.tag == 0x574353) [v removeFromSuperview];
    cell.backgroundView = nil;
    LYHWSetBackgroundIfChanged(cell, [UIColor clearColor]); cell.layer.backgroundColor = nil;
    cell.layer.cornerRadius = 0; cell.layer.mask = nil;
    cell.layer.shadowOpacity = 0; cell.layer.shadowPath = NULL;
    cell.contentView.frame = cell.bounds;
    LYHWSetBackgroundIfChanged(cell.contentView, [UIColor clearColor]);
    cell.contentView.layer.backgroundColor = nil;
    cell.contentView.layer.cornerRadius = 0;
    LYHWClearGroupInfoContent(cell.contentView, 0);
    // 微信把部分内容直接加在 cell 上而不是 contentView 上，只清大容器底板。
    for (UIView *v in cell.subviews) {
        if (v == existing || v == cell.contentView || [v isKindOfClass:[UILabel class]] ||
            [v isKindOfClass:[UIImageView class]] || [v isKindOfClass:[UIButton class]]) continue;
        LYHWSetBackgroundIfChanged(v, [UIColor clearColor]); v.layer.backgroundColor = nil;
    }
    LYHWHideLines(cell);
    // 用整个连续分组的路径裁每一行：短小的“更多群成员”行也不会被圆成一条白色梭形。
    CGRect block = LYHWGroupBlockRect(tv, ip);
    LYHWCardView *card = [existing isKindOfClass:[LYHWCardView class]] ? (LYHWCardView *)existing : nil;
    if (!card) { [existing removeFromSuperview]; card = [LYHWCardView new]; card.tag = 0x45e0; card.userInteractionEnabled = NO; }
    CGFloat desired = MAX(0, configuredMargin);
    // 如系统已内缩，不再重复叠加同一份边距。
    CGRect row = [tv convertRect:cell.bounds fromView:cell];
    CGFloat margin = MAX(0, desired - MAX(0, CGRectGetMinX(row)));
    margin = MIN(margin, cell.bounds.size.width * 0.45);
    LYHWSetCardFrame(card, CGRectInset(cell.bounds, margin, 0));
    LYHWSetBackgroundIfChanged(card, LYHWCachedPalette1());
    CGFloat radius = MIN(MAX(0, configuredRadius), card.bounds.size.width / 2);
    CGFloat blockY = CGRectGetMinY(block) - CGRectGetMinY([tv rectForRowAtIndexPath:ip]);
    CGRect blockInCard = CGRectMake(0, blockY, card.bounds.size.width, block.size.height);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:blockInCard cornerRadius:radius];
    CAShapeLayer *mask = [card.layer.mask isKindOfClass:[CAShapeLayer class]] ? (CAShapeLayer *)card.layer.mask : [CAShapeLayer layer];
    mask.frame = card.bounds; mask.path = path.CGPath;
    card.layer.mask = mask;
    // 只能由上面的路径决定首尾角，绝不能再设默认四角圆角。
    card.layer.cornerRadius = 0;
    if (card.superview != cell) [cell insertSubview:card atIndex:0]; else [cell sendSubviewToBack:card];
    // 内容层按同一路径裁掉四周原生白底，保护文字/按钮的原有布局。
    CGRect blockInContent = CGRectMake(CGRectGetMinX(card.frame), blockY, card.bounds.size.width, block.size.height);
    UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:blockInContent cornerRadius:radius];
    CAShapeLayer *cm = [CAShapeLayer layer]; cm.name = @"LYHWGroupClipMask";
    cm.frame = cell.contentView.bounds; cm.path = clip.CGPath; cell.contentView.layer.mask = cm;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (!cell.selectedBackgroundView || cell.selectedBackgroundView.tag != 0x45e1) {
        UIView *sel = [UIView new]; sel.tag = 0x45e1; LYHWSetBackgroundIfChanged(sel, UIColor.clearColor); cell.selectedBackgroundView = sel;
    }
}


static BOOL gLYHWInStyle = NO;
static void LYHWStyleCellCardInner(UITableViewCell *cell);
static void LYHWStyleCellCard(UITableViewCell *cell) {
    if (!cell || gLYHWInStyle) return;
    gLYHWInStyle = YES;
    @try {
        LYHWStyleCellCardInner(cell);
    } @finally {
        gLYHWInStyle = NO;
    }
}
static void LYHWStyleCellCardInner(UITableViewCell *cell) {
    if (!cell) return;
    // 不在这里藏阴影宿主：转场期间每帧都会重套，cell 偶尔暂时查不到 indexPath 就会提前返回，
    // 先藏后不显示 → 整块阴影逐帧闪。旧宿主由 prepareForReuse 负责藏，需要显示/隐藏由 Apply 决定。
    if (LYHWClassExcluded(NSStringFromClass([cell class]))) return;
    UITableView *tv = nil;
    for (UIView *v = cell.superview; v; v = v.superview)
        if ([v isKindOfClass:[UITableView class]]) { tv = (UITableView *)v; break; }
    if (!tv) return;
    // 群聊资料页与单聊详情页由各自的开关驱动，同一条整块卡片路径。
    if (LYHWIsGroupInfoTable(tv)) {
        LYHWStyleGroupInfoCell(cell);
        return;
    }
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
    BOOL actualSettingsPage = settingPage && !profileLike;
    if (settingPage) kind = 4;
    BOOL timeline = (kind == 5);
    if (timeline && !c.timelineCornerEnabled) return;
    if (timeline) kind = 1;  // 朋友圈改为和主页一样，每行独立卡片
    if ((kind == 1 && !timeline && !c.mainFrameCornerEnabled) || (kind == 2 && !c.homepageCornerEnabled) ||
        (kind == 3 && !c.myPageCornerEnabled) || (kind == 4 && !settingPage && !c.discoverPageCornerEnabled)) return;
    BOOL fancy = (kind != 4);
        CGFloat radius = kind == 1 ? 22.0 : (kind == 3 ? (c.myPageCornerRadius > 0 ? c.myPageCornerRadius : 24.0) : fancy ? 24.0 : (c.globalCornerRadius > 0 ? c.globalCornerRadius : 28.0));
    CGFloat margin = kind == 1 ? 9.0 : (kind == 2 ? 10.0 : (kind == 3 ? (c.myPageCornerMargin > 0 ? c.myPageCornerMargin : 20.0) : fancy ? 20.0 : (c.globalCornerMargin > 0 ? c.globalCornerMargin : 18.0)));
    if (kind == 7) { radius = c.profilePageCornerRadius > 0 ? c.profilePageCornerRadius : 24.0; margin = c.profilePageCornerMargin; }
    if (actualSettingsPage) {
        radius = MAX(0, MIN(60, c.settingPageCornerRadius));
        margin = MAX(0, MIN(40, c.settingPageCornerMargin));
    }
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
        cell.backgroundView = nil; cell.selectedBackgroundView = nil; LYHWSetBackgroundIfChanged(cell, [UIColor clearColor]);
        LYHWSetBackgroundIfChanged(cell.contentView, [UIColor clearColor]);
        for (UIView *sv in cell.contentView.subviews) { LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]); sv.hidden = YES; }
        return;
    }
    BOOL isFirstRow = (ip.section == secFirst && ip.row <= fr);
    BOOL isLastRow = (ip.section == secLast && ip.row >= lr);

    // 列表底色：浅灰，卡片为白
    UIColor *bg = LYHWListGray();
    LYHWSetBackgroundIfChanged(tv, bg);
    tv.separatorStyle = UITableViewCellSeparatorStyleNone;
    tv.sectionIndexBackgroundColor = [UIColor clearColor];
    tv.sectionIndexTrackingBackgroundColor = [UIColor clearColor];
    if (fancy) tv.clipsToBounds = NO;

    LYHWSetBackgroundIfChanged(cell, [UIColor clearColor]);
    LYHWSetBackgroundIfChanged(cell.contentView, [UIColor clearColor]);
    cell.layer.backgroundColor = [UIColor clearColor].CGColor;
    for (UIView *sv in cell.subviews) {
        if (sv == cell.contentView || sv == cell.backgroundView || sv == cell.selectedBackgroundView || sv.tag == 0x574353) continue;
        if ([NSStringFromClass([sv class]) rangeOfString:@"Separator"].location != NSNotFound) continue;
        if (sv.bounds.size.height >= cell.bounds.size.height * 0.8) { LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]); sv.layer.backgroundColor = [UIColor clearColor].CGColor; }
    }
    UIView *card = cell.backgroundView;
    if (!card || card.tag != 0x574352 || ![card isKindOfClass:[LYHWCardView class]]) {
        card = [LYHWCardView new];
        card.tag = 0x574352;
        card.userInteractionEnabled = NO;
        cell.backgroundView = card;
    }
    // 同组整块：上下不留缝，只有首尾行有圆角
    LYHWSetCardFrame(card, CGRectMake(margin, 0, cell.bounds.size.width - margin * 2, cell.bounds.size.height));
    LYHWSetBackgroundIfChanged(card, (kind == 1 && !timeline) ? LYHWCachedPalette2() : LYHWCardFill());
    if (kind == 1 && !timeline) {
        tv.backgroundView = nil;
        // Paint only the table's backing host. Full-screen children can be
        // foreground UIKit scroll-edge/touch passthrough containers, not backdrops.
        // Making those opaque hides every real conversation cell underneath.
        if (tv.superview) LYHWSetBackgroundIfChanged(tv.superview, bg);
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
        LYHWSetCardFrame(card, f);
        if (m == 0) card.layer.cornerRadius = 0;
    } else if (m == 0) card.layer.cornerRadius = 0;
    {
        UIView *sel = cell.selectedBackgroundView;
        // 选中背景也必须锁 frame：长按高亮时 UIKit 会把它重设成整个 cell，盖住卡片外的留白
        if (!sel || sel.tag != 0x574353 || ![sel isKindOfClass:[LYHWCardView class]]) {
            sel = [LYHWCardView new]; sel.tag = 0x574353; sel.userInteractionEnabled = NO;
            cell.selectedBackgroundView = sel;
        }
        LYHWSetCardFrame(sel, card.frame);
        if (c.cellTapEffectHidden) {
            // 隐藏点击特效：选中背景全透明，点按时不出现任何灰底
            LYHWSetBackgroundIfChanged(sel, [UIColor clearColor]);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            LYHWSetBackgroundIfChanged(sel, LYHWCachedPalette3());
        }
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
                    LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]);
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
        LYHWSetBackgroundIfChanged(cell, [UIColor clearColor]);
        if (cf.origin.x != 0) cell.contentView.frame = CGRectMake(0, cf.origin.y, cell.bounds.size.width, cf.size.height);
        LYHWSetCardFrame(card, CGRectMake(mg, 0, cell.bounds.size.width - mg * 2, cell.bounds.size.height));
        for (UIView *sv in cell.subviews) {
            if (sv == cell.contentView || sv == card || sv.tag == 0x574353) continue;
            if (sv.bounds.size.width > cell.bounds.size.width - mg * 2 + 0.5 && sv.bounds.size.height > 4) {
                LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]);
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
                    if ([sv.backgroundColor getWhite:&w alpha:&a] && w > 0.97 && a > 0.5) LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]);
                }
                if (sv.bounds.size.width >= cw * 0.8) [st addObject:sv];
            }
        }
        cell.contentView.layer.cornerRadius = 0;
        cell.clipsToBounds = NO;
    }
    LYHWApplyCardShadow(cell, card, c, isLastRow);
    LYHWConstrainSwipeViews(cell, card);
    LYHWScheduleSwipeRescan(cell, card);
}



// 按下/选中瞬间：选中背景对齐卡片；微信自带的整行高亮底（比卡片宽）清透明
static void LYHWFixPressedState(UITableViewCell *cell) {
    UIView *card = cell.backgroundView;
    if (!card || card.tag != 0x574352) return;
    UIView *sel = cell.selectedBackgroundView;
    if (sel && sel.tag == 0x574353) LYHWSetCardFrame(sel, card.frame);
    if (LYHWCCfg().cellTapEffectHidden) {
        if (sel) LYHWSetBackgroundIfChanged(sel, [UIColor clearColor]);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        // 微信有些 cell 自己画高亮底（按下时才出现），一并清掉
        for (UIView *sv in cell.subviews) {
            if (sv == cell.contentView || sv == card || sv == sel) continue;
            if (sv.tag == 0x574352 || sv.tag == 0x574353) continue;
            UIColor *bc = sv.backgroundColor;
            if (!bc) continue;
            CGFloat w = 0, a = 0;
            if ([bc getWhite:&w alpha:&a] && a > 0.02 && w < 0.97 &&
                sv.bounds.size.height >= cell.bounds.size.height * 0.6) {
                LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]);
                sv.layer.backgroundColor = nil;
            }
        }
    }
    // 长按/选中期间锁定状态：不要让微信的中间态触发一次恢复阴影，
    // 否则阴影挂在最后一行 cell.layer 上，会随那一行的高亮/菜单动画一起移动。
    {
        BOOL pressed = cell.highlighted || cell.selected;
        LYHWSetPressActive(cell, pressed);
        NSIndexPath *ip = nil;
        UITableView *tv = nil;
        for (UIView *v = cell.superview; v; v = v.superview) if ([v isKindOfClass:[UITableView class]]) { tv = (UITableView *)v; break; }
        if (tv) ip = [tv indexPathForCell:cell];
        if (pressed) {
            [CATransaction begin]; [CATransaction setDisableActions:YES];
            cell.layer.shadowOpacity = 0;
            cell.layer.shadowPath = NULL;
            [CATransaction commit];
        } else if (ip) {
            LYHWStyleCellCard(cell);
        }
    }
    CGFloat cw = card.bounds.size.width;
    for (UIView *sv in cell.subviews) {
        if (sv == cell.contentView || sv == card || sv == sel) continue;
        if (sv.tag == 0x574352 || sv.tag == 0x574353 || sv.tag == 0x574357) continue;
        if (sv.bounds.size.width > cw + 1 && sv.bounds.size.height >= cell.bounds.size.height * 0.8) {
            LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]);
            sv.layer.backgroundColor = nil;
        }
    }
}

%hook UITableViewCell
- (void)setClipsToBounds:(BOOL)clip {
    // 阴影挂在 cell.layer 上，一旦被裁剪就会齐边切掉，所以有阴影时不允许打开裁剪
    if (clip && self.layer.shadowPath != NULL && self.layer.shadowOpacity > 0.001) clip = NO;
    %orig(clip);
}
// 微信在转场开头会把 backgroundView / backgroundColor 重置回原生，卡片被换掉，前几帧就是直通白条。
// 这里不让别人替换我们的卡片，并在被改背景色后立刻补回样式。
- (void)setBackgroundView:(UIView *)v {
    if (!gLYHWInStyle) {
        UIView *cur = [(UITableViewCell *)self backgroundView];
        if (cur && cur.tag == 0x574352 && v != cur) return;
    }
    %orig;
}
- (void)setBackgroundColor:(UIColor *)c {
    %orig;
    if (gLYHWInStyle || !LYHWAnyCardOn()) return;
    UIView *cur = [(UITableViewCell *)self backgroundView];
    if (cur && cur.tag == 0x574352) LYHWStyleCellCard((UITableViewCell *)self);
}
- (void)setFrame:(CGRect)f {
    %orig;
    if (gLYHWInStyle || !LYHWAnyCardOn()) return;
    UIView *cur = [(UITableViewCell *)self backgroundView];
    if (cur && cur.tag == 0x574352 && !self.isHidden) LYHWStyleCellCard((UITableViewCell *)self);
}
- (void)didMoveToWindow {
    %orig;
    if (self.window && LYHWAnyCardOn()) LYHWStyleCellCard((UITableViewCell *)self);
}
- (void)prepareForReuse {
    %orig;
    UITableViewCell *cell = (UITableViewCell *)self;
    LYHWSetPressActive(cell, NO);
    LYHWHideShadowHost(cell);
    [[cell viewWithTag:0x45e0] removeFromSuperview];
    if ([cell.contentView.layer.mask.name isEqualToString:@"LYHWGroupClipMask"]) cell.contentView.layer.mask = nil;
    if (cell.selectedBackgroundView.tag == 0x45e1) cell.selectedBackgroundView = nil;
}
- (void)setHighlighted:(BOOL)h animated:(BOOL)a {
    %orig;
    if (LYHWAnyCardOn()) LYHWFixPressedState((UITableViewCell *)self);
}
- (void)setSelected:(BOOL)sel animated:(BOOL)a {
    %orig;
    if (LYHWAnyCardOn()) LYHWFixPressedState((UITableViewCell *)self);
}
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
            LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]);
            sv.layer.backgroundColor = nil; sv.layer.cornerRadius = 0;
            if (([sv isKindOfClass:[UIImageView class]] || [sv isKindOfClass:[UIVisualEffectView class]]) && sv.subviews.count == 0) { sv.hidden = YES; continue; }
        }
        if ([sv isKindOfClass:[UILabel class]] || [sv isKindOfClass:[UIImageView class]] || [sv isKindOfClass:[UIButton class]]) continue;
        // 头部里横穿整屏的窄白条（原生分段底色）：刷成列表灰，避免从卡片圆角外露白
        if (sw >= stopW * 0.9 && sh > 1.5 && sh <= 30) {
            CGFloat w = 0, a = 0;
            UIColor *c0 = sv.backgroundColor;
            if (c0 && [c0 getWhite:&w alpha:&a] && a > 0.02 && w > 0.9) {
                LYHWSetBackgroundIfChanged(sv, LYHWListGray());
                sv.layer.backgroundColor = nil;
            }
        }
        if (sv.subviews.count > 0 && sv.bounds.size.height > 40) LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]);
        LYHWClearBg(sv, stop);
    }
}

static void LYHWFlatWhite(UIView *v, UIColor *c, CGFloat W) {
    for (UIView *sv in v.subviews) {
        if ([sv isKindOfClass:[UILabel class]] || [sv isKindOfClass:[UIButton class]]) continue;
        if (sv.bounds.size.width >= W * 0.85 && sv.bounds.size.height >= 60) {
            LYHWSetBackgroundIfChanged(sv, c); sv.layer.cornerRadius = 0; sv.layer.backgroundColor = c.CGColor;
        }
        LYHWFlatWhite(sv, c, W);
    }
}
// 只把列表自身及其父视图、头部容器的底色刷成列表灰，
// 不碰卡片、不碰 cell 内部的任何视图，避免把卡片本身清成透明/灰色。
static void LYHWPaintListSurface(UITableView *tv, UIView *header) {
    UIColor *bg = LYHWListGray();
    LYHWSetBackgroundIfChanged(tv, bg);
    tv.backgroundView = nil;
    if (header) LYHWSetBackgroundIfChanged(header, bg);
    UIView *host = tv.superview;
    if (host) {
        CGFloat w = 0, a = 0;
        UIColor *hc = host.backgroundColor;
        BOOL whiteish = NO;
        if (hc && [hc getWhite:&w alpha:&a]) whiteish = (a > 0.02 && w > 0.9);
        if (whiteish) LYHWSetBackgroundIfChanged(host, bg);
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
                LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]);
                sv.layer.backgroundColor = nil;
            }
        }
        if (![sv isKindOfClass:[UILabel class]] && ![sv isKindOfClass:[UIImageView class]] && ![sv isKindOfClass:[UIButton class]])
            LYHWClearWiderWhite(sv, cardW, card, depth + 1);
    }
}

// 头部卡片原来直接铺满整个 tableHeaderView 的高度，
// 而微信的头部底部还留了一段空白/分隔区，卡片就会在内容下面多出一截空白再收圆角。
// 这里按「真实内容」的最低点来收口：只统计可见的叶子视图与图文控件，忽略整块容器和细线。
static BOOL LYHWVisibleInk(UIView *v) {
    // 真正「看得见的内容」：有文字的 label、有图的 imageView、按钮、成员网格，
    // 或者自身有不透明底色的小块。透明占位容器一律不算。
    if ([v isKindOfClass:[UILabel class]]) return ((UILabel *)v).text.length > 0;
    if ([v isKindOfClass:[UIImageView class]]) return ((UIImageView *)v).image != nil;
    if ([v isKindOfClass:[UIButton class]]) return YES;
    if ([v isKindOfClass:[UICollectionView class]]) return YES;
    UIColor *bc = v.backgroundColor;
    if (bc && CGColorGetAlpha(bc.CGColor) > 0.05) {
        CGFloat w = 0, a = 0;
        // 纯白/接近白的大块通常是微信自己的底板，不算内容
        if ([bc getWhite:&w alpha:&a] && w > 0.93 && v.bounds.size.height > 20) return NO;
        return YES;
    }
    if (v.layer.contents != nil) return YES;
    return NO;
}

static void LYHWCollectContentBottom(UIView *v, UIView *skip, UIView *root, CGFloat *maxY, int depth) {
    if (depth > 7) return;
    for (UIView *sv in v.subviews) {
        if (sv == skip || sv.hidden || sv.alpha < 0.01) continue;
        if (sv.tag == 0x574354 || sv.tag == 0x574355 || sv.tag == 0x574356) continue;
        CGSize z = sv.bounds.size;
        if (z.width < 1 || z.height <= 1.5) continue;
        if (LYHWVisibleInk(sv)) {
            CGRect r = [sv convertRect:sv.bounds toView:root];
            if (CGRectGetMaxY(r) > *maxY) *maxY = CGRectGetMaxY(r);
        }
        if (![sv isKindOfClass:[UICollectionView class]] && ![sv isKindOfClass:[UITableView class]])
            LYHWCollectContentBottom(sv, skip, root, maxY, depth + 1);
    }
}

static CGFloat LYHWHeaderCardHeight(UIView *h, UIView *card, CGFloat top, CGFloat fallback) {
    CGFloat maxY = 0;
    LYHWCollectContentBottom(h, card, h, &maxY, 0);
    if (maxY <= top + 20) return fallback;
    CGFloat want = maxY - top + 16.0;      // 内容下方留 16pt
    if (want < 60) want = 60;
    if (want > fallback) want = fallback;
    return want;
}

static void LYHWStyleInfoHeader(UITableView *tv) {
    UIView *h = tv.tableHeaderView;
    if (!h || h.bounds.size.width < 100 || h.bounds.size.height < 60) return;
    CGFloat W = h.bounds.size.width, H = h.bounds.size.height;
    LYHWConfig *pc = LYHWCCfg();
    CGFloat pm = MAX(0, MIN(pc.profilePageCornerMargin, W * 0.45));
    CGFloat pr = pc.profilePageCornerRadius > 0 ? pc.profilePageCornerRadius : 24.0;
    UIView *card = [h viewWithTag:0x574355];
    if (!card) { card = [UIView new]; card.tag = 0x574355; card.userInteractionEnabled = NO; [h insertSubview:card atIndex:0]; }
    CGFloat cardH = LYHWHeaderCardHeight(h, card, 4, H - 12);
    card.frame = CGRectMake(pm, 4, W - pm * 2, cardH);
    LYHWSetBackgroundIfChanged(card, LYHWCachedPalette4());
    card.layer.cornerRadius = pr;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    {
        double hst = LYHWCCfg().cardShadowEnabled ? MAX(0.0, MIN(1.0, LYHWCCfg().cardShadowStrength)) : 0.0;
        // 阴影画在头部视图图层上（卡片自己不裁剪也可以，但统一放到 h 上，与 cell 一致）
        h.clipsToBounds = NO;
        LYHWSetSinkShadow(h.layer, card.frame, pr, kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner, hst);
    }
    LYHWSetBackgroundIfChanged(h, [UIColor clearColor]);
    stopW = W;
    LYHWClearBg(h, card);
    LYHWClearWiderWhite(h, card.bounds.size.width, card, 0);
    LYHWPaintListSurface(tv, h);
    // 卡片收口后，头部自身也要跟着收，否则卡片下方会多出一段空白
    CGFloat wantH = CGRectGetMaxY(card.frame) + 8.0;
    if (wantH > 40 && fabs(h.bounds.size.height - wantH) > 1.0 && wantH < H) {
        CGRect hf = h.frame; hf.size.height = wantH; h.frame = hf;
        tv.tableHeaderView = h;
    }
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
    LYHWSetBackgroundIfChanged(card, LYHWCachedPalette5());
    card.layer.cornerRadius = 24;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    {
        double hst = LYHWCCfg().cardShadowEnabled ? MAX(0.0, MIN(1.0, LYHWCCfg().cardShadowStrength)) : 0.0;
        // 阴影跟随卡片自身，不再挂到整宽 header 底板上。
        LYHWSetSinkShadow(h.layer, CGRectZero, 0, 0, 0);
        card.clipsToBounds = NO;
        LYHWSetSinkShadow(card.layer, card.bounds, 24, kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner, hst);
    }
    LYHWSetBackgroundIfChanged(h, [UIColor clearColor]);
    stopW = W;
    LYHWClearBg(h, card);
    LYHWClearWiderWhite(h, card.bounds.size.width, card, 0);
    LYHWPaintListSurface(tv, nil); // header 保持透明，消除底部整宽硬切线
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

// 页脚（如通讯录底部「130 个朋友」）是不透明白底，会盖住列表灰底，
// 还会把卡片底部阴影在页脚上缘处切断。把页脚里整宽的白底清成透明，露出列表灰。
static void LYHWClearFooterTree(UIView *v, CGFloat W, int depth) {
    if (!v || depth > 3) return;
    for (UIView *sv in v.subviews) {
        if ([sv isKindOfClass:[UILabel class]] || [sv isKindOfClass:[UIImageView class]] || [sv isKindOfClass:[UIButton class]]) continue;
        if (sv.bounds.size.width >= W * 0.8) {
            CGFloat w = 0, a = 0;
            UIColor *c0 = sv.backgroundColor;
            if (c0 && [c0 getWhite:&w alpha:&a] && a > 0.02 && w > 0.9) { LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]); sv.layer.backgroundColor = nil; }
        }
        LYHWClearFooterTree(sv, W, depth + 1);
    }
}
static void LYHWPaintFooter(UITableView *tv) {
    UIView *f = tv.tableFooterView;
    if (!f || f.bounds.size.height < 1) return;
    LYHWSetBackgroundIfChanged(f, [UIColor clearColor]);
    f.layer.backgroundColor = nil;
    LYHWClearFooterTree(f, tv.bounds.size.width, 0);
}

// 分组之间的头/尾视图默认是不透明的整宽灰底，层级在 cell 之上，
// 会把上一张卡片的阴影齐刷刷切掉，留下一条条硬边的「小白条」。这里统一清成透明。
static void LYHWClearHFView(UIView *v) {
    LYHWSetBackgroundIfChanged(v, [UIColor clearColor]);
    v.layer.backgroundColor = nil;
    if ([v isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *hf = (UITableViewHeaderFooterView *)v;
        if (hf.backgroundView) { LYHWSetBackgroundIfChanged(hf.backgroundView, [UIColor clearColor]); hf.backgroundView.hidden = YES; }
        LYHWSetBackgroundIfChanged(hf.contentView, [UIColor clearColor]);
        if (@available(iOS 14.0, *)) {
            UIBackgroundConfiguration *bc = [UIBackgroundConfiguration clearConfiguration];
            hf.backgroundConfiguration = bc;
        }
    }
    for (UIView *sv in v.subviews) {
        if ([sv isKindOfClass:[UILabel class]] || [sv isKindOfClass:[UIImageView class]] || [sv isKindOfClass:[UIButton class]]) continue;
        if (sv.bounds.size.width >= v.bounds.size.width * 0.9) {
            LYHWSetBackgroundIfChanged(sv, [UIColor clearColor]);
            sv.layer.backgroundColor = nil;
        }
    }
}

static void LYHWClearSectionBars(UITableView *tv) {
    CGFloat W = tv.bounds.size.width;
    for (UIView *v in tv.subviews) {
        if ([v isKindOfClass:[UITableViewCell class]] || v == tv.tableHeaderView || v == tv.tableFooterView) continue;
        if ([v isKindOfClass:[UIImageView class]] && v.bounds.size.width < 10) continue; // 滚动条
        BOOL hfClass = [v isKindOfClass:[UITableViewHeaderFooterView class]] ||
                       [NSStringFromClass([v class]) rangeOfString:@"HeaderFooter"].location != NSNotFound ||
                       [NSStringFromClass([v class]) rangeOfString:@"SectionHeader"].location != NSNotFound;
        BOOL wideBar = v.bounds.size.width >= W * 0.9 && v.bounds.size.height > 1.5 && v.bounds.size.height < 80 && v.backgroundColor &&
                       CGColorGetAlpha(v.backgroundColor.CGColor) > 0.02;
        if (hfClass || wideBar) LYHWClearHFView(v);
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
    {
        NSInteger fk = LYHWPageKind(self);
        if (fk == 1 || fk == 2 || fk == 4 || fk == 5 || fk == 6) LYHWPaintFooter((UITableView *)self);
    }
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
    // 好友资料页继续使用用户自己的头部实现；群聊资料页改走源码式逐行卡片，
    // 不再套 LYHWStyleInfoHeader，避免与 NewChatRoomMemberContainView 清理逻辑叠加。
    else if (LYHWCCfg().profilePageCornerEnabled && LYHWPageKind(self) == 7) LYHWStyleInfoHeader((UITableView *)self);
    [objc_getAssociatedObject(self, @selector(LYHWGroupInfo)) removeAllObjects];
    for (UITableViewCell *cell in [(UITableView *)self visibleCells]) LYHWStyleCellCard(cell);
    if (LYHWPageKind(self) != 0) LYHWClearSectionBars((UITableView *)self);
}
%end


// ===== 朋友圈图片/视频圆角：视频播放/加载/预览回来时被 WeChat 重置，需要在媒体视图自己布局时补回 =====
static void LYHWRoundTimelineMediaSelf(UIView *v) {
    LYHWConfig *c = LYHWCCfg();
    if (!c.timelineCornerEnabled || !c.timelineMediaCornerEnabled) return;
    CGSize z = v.bounds.size;
    if (z.width < 60 || z.height < 60 || z.width >= [UIScreen mainScreen].bounds.size.width - 40) return;
    if (LYHWPageKind(v) != 5) return;
    CALayer *l = v.layer;
    if (l.cornerRadius < 1 || !l.masksToBounds) {
        l.cornerRadius = c.timelineMediaCornerRadius; l.masksToBounds = YES; v.clipsToBounds = YES;
        if (@available(iOS 13.0, *)) l.cornerCurve = kCACornerCurveContinuous;
    }
}
static void LYHWRoundTimelineTemplate(UIView *v) {
    LYHWConfig *c = LYHWCCfg();
    if (!c.timelineCornerEnabled || !c.timelineMediaCornerEnabled) return;
    if (LYHWPageKind(v) != 5) return;
    LYHWRoundMedia(v, v);
}
// ===== 朋友圈真实媒体类（来自类库）：九宫格单格 WCImageView、视频 WCSNSNodeVideoView =====
// 圆角挂在控件自身 layer 上；预览关闭动画结束(showViewWhenCloseFullScreenAnimationEnd)时 WeChat 会重置，必须当场补回
static void LYHWRoundExact(UIView *v) {
    LYHWConfig *c = LYHWCCfg();
    if (!v || !c.timelineCornerEnabled || !c.timelineMediaCornerEnabled) return;
    CGSize z = v.bounds.size;
    if (z.width < 30 || z.height < 30) return;
    CALayer *l = v.layer;
    CGFloat r = c.timelineMediaCornerRadius;
    if (fabs(l.cornerRadius - r) < 0.5 && l.masksToBounds) return;
    [UIView performWithoutAnimation:^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        l.cornerRadius = r; l.masksToBounds = YES; v.clipsToBounds = YES;
        if (@available(iOS 13.0, *)) l.cornerCurve = kCACornerCurveContinuous;
        [CATransaction commit];
    }];
}
%hook WCImageView
- (void)layoutSubviews {
    %orig;
    LYHWRoundExact((UIView *)self);
}
- (void)showViewWhenCloseFullScreenAnimationEnd {
    %orig;
    LYHWRoundExact((UIView *)self);
}
- (void)hideViewWhenShowFullScreenAnimationEnd {
    %orig;
    LYHWRoundExact((UIView *)self);
}
%end
%hook WCSNSNodeVideoView
- (void)layoutSubviews {
    %orig;
    LYHWRoundExact((UIView *)self);
}
- (void)showViewWhenCloseFullScreenAnimationEnd {
    %orig;
    LYHWRoundExact((UIView *)self);
}
- (void)hideViewWhenShowFullScreenAnimationEnd {
    %orig;
    LYHWRoundExact((UIView *)self);
}
%end

// ===== 预览飞入/飞回动画：飞行的视图是预览页自己的（原生直角），需要让它的圆角随动画渐变 =====
static UIView *LYHWSafeView(id obj, NSString *key) {
    @try {
        id v = [obj valueForKey:key];
        return [v isKindOfClass:[UIView class]] ? (UIView *)v : nil;
    } @catch (__unused NSException *e) { return nil; }
}
static void LYHWAnimateFlyCorner(UIView *v, BOOL toRound, CFTimeInterval dur) {
    LYHWConfig *c = LYHWCCfg();
    if (!v || !c.timelineCornerEnabled || !c.timelineMediaCornerEnabled) return;
    CGFloat r = c.timelineMediaCornerRadius;
    CALayer *l = v.layer;
    CGFloat from = toRound ? 0 : r;
    CGFloat to = toRound ? r : 0;
    l.masksToBounds = YES;
    if (@available(iOS 13.0, *)) l.cornerCurve = kCACornerCurveContinuous;
    l.cornerRadius = to;
    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
    a.fromValue = @(from); a.toValue = @(to);
    a.duration = dur;
    a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [l addAnimation:a forKey:@"LYHWFlyCorner"];
}
%hook WCImageFullScreenViewContainer
- (void)animationHideWithRotate {
    %orig;
    UIView *fly = LYHWSafeView(self, @"m_container");
    LYHWAnimateFlyCorner(fly, YES, 0.28);
}
- (void)animationShowView {
    %orig;
    UIView *fly = LYHWSafeView(self, @"m_container");
    LYHWAnimateFlyCorner(fly, NO, 0.28);
}
%end
static void LYHWAnimateVideoFly(id vc, BOOL toRound) {
    UIView *box = LYHWSafeView(vc, @"playerViewContainer");
    LYHWAnimateFlyCorner(box, toRound, 0.28);
    LYHWAnimateFlyCorner(LYHWSafeView(box, @"playerView"), toRound, 0.28);
    LYHWAnimateFlyCorner(LYHWSafeView(vc, @"playerView"), toRound, 0.28);
    LYHWAnimateFlyCorner(LYHWSafeView(vc, @"fullScreenContent"), toRound, 0.28);
}
%hook WCPlayerConfigFullScreenViewController
- (void)showVCAnimation {
    %orig;
    LYHWAnimateVideoFly(self, NO);
}
- (void)stopAndCloseFullScreenWindowAnimated:(BOOL)animated withCompletion:(id)completion {
    if (animated) LYHWAnimateVideoFly(self, YES);
    %orig;
}
- (void)onFullScreenClose {
    LYHWAnimateVideoFly(self, YES);
    %orig;
}
- (void)onFullScreenDragEnd {
    LYHWAnimateVideoFly(self, YES);
    %orig;
}
%end

%hook WCSightView
- (void)layoutSubviews {
    %orig;
    LYHWRoundTimelineMediaSelf((UIView *)self);
}
%end
%hook SightView
- (void)layoutSubviews {
    %orig;
    LYHWRoundTimelineMediaSelf((UIView *)self);
}
%end
%hook WCContentItemViewTemplateGrid
- (void)layoutSubviews {
    %orig;
    LYHWRoundTimelineTemplate((UIView *)self);
}
%end
%hook WCContentItemViewTemplateClassic
- (void)layoutSubviews {
    %orig;
    LYHWRoundTimelineTemplate((UIView *)self);
}
%end
%hook WCContentItemViewTemplateVideo
- (void)layoutSubviews {
    %orig;
    LYHWRoundTimelineTemplate((UIView *)self);
}
%end
%hook WCContentItemViewTemplateNewSight
- (void)layoutSubviews {
    %orig;
    LYHWRoundTimelineTemplate((UIView *)self);
}
%end

// ===== 预览返回：朋友圈页面出现的整个动画期间，每帧给可见 cell 里的媒体补圆角 =====
static void LYHWFindTables(UIView *v, NSMutableArray *out, int depth) {
    if (depth > 6) return;
    if ([v isKindOfClass:[UITableView class]]) { [out addObject:v]; return; }
    for (UIView *sv in v.subviews) LYHWFindTables(sv, out, depth + 1);
}
static void LYHWSweepTimelineMedia(UIView *root) {
    LYHWConfig *c = LYHWCCfg();
    if (!root || !c.timelineCornerEnabled || !c.timelineMediaCornerEnabled) return;
    NSMutableArray *tabs = [NSMutableArray array];
    LYHWFindTables(root, tabs, 0);
    Class cImg = NSClassFromString(@"WCImageView"), cVid = NSClassFromString(@"WCSNSNodeVideoView");
    for (UITableView *tv in tabs) {
        for (UITableViewCell *cell in tv.visibleCells) {
            LYHWRoundMedia(cell, cell);
            NSMutableArray *st = [NSMutableArray arrayWithObject:cell];
            while (st.count) {
                UIView *v = st.lastObject; [st removeLastObject];
                for (UIView *sv in v.subviews) {
                    if ((cImg && [sv isKindOfClass:cImg]) || (cVid && [sv isKindOfClass:cVid])) LYHWRoundExact(sv);
                    else [st addObject:sv];
                }
            }
        }
    }
}
@interface LYHWTimelineLink : NSObject
@property (nonatomic, weak) UIView *root;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) CFTimeInterval until;
- (void)tick:(CADisplayLink *)l;
@end
@implementation LYHWTimelineLink
- (void)tick:(CADisplayLink *)l {
    UIView *r = self.root;
    if (!r || CACurrentMediaTime() > self.until) { [l invalidate]; self.link = nil; return; }
    [UIView performWithoutAnimation:^{ LYHWSweepTimelineMedia(r); }];
}
@end
static void LYHWStartTimelineSweep(UIViewController *vc, CFTimeInterval dur) {
    if (!vc.isViewLoaded) return;
    static const void *kKey = &kKey;
    LYHWTimelineLink *h = objc_getAssociatedObject(vc, kKey);
    if (!h) { h = [LYHWTimelineLink new]; objc_setAssociatedObject(vc, kKey, h, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    h.root = vc.view;
    h.until = CACurrentMediaTime() + dur;
    LYHWSweepTimelineMedia(vc.view);
    if (!h.link) {
        h.link = [CADisplayLink displayLinkWithTarget:h selector:@selector(tick:)];
        [h.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

// ===== 从朋友圈返回发现页/主页：cell 被复用，阴影宿主还是旧的（错位的第二层）；页面出现时统一重排 =====
static void LYHWRestyleVisibleCells(UIView *root) {
    NSMutableArray *tabs = [NSMutableArray array];
    LYHWFindTables(root, tabs, 0);
    for (UITableView *tv in tabs) {
        [UIView performWithoutAnimation:^{
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            for (UITableViewCell *cell in tv.visibleCells) {
                LYHWStyleCellCard(cell);   // 主动套一次，不依赖 layoutSubviews 是否被触发
            }
            [CATransaction commit];
        }];
    }
}
@interface LYHWRestyleLink : NSObject
@property (nonatomic, weak) UIViewController *vc;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) CFTimeInterval deadline;
@end
@implementation LYHWRestyleLink
- (void)tick:(CADisplayLink *)l {
    UIViewController *vc = self.vc;
    if (!vc || !vc.isViewLoaded || CACurrentMediaTime() > self.deadline) {
        [l invalidate]; self.link = nil;
        if (vc) objc_setAssociatedObject(vc, @selector(tick:), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    LYHWRestyleVisibleCells(vc.view);
}
@end
static void LYHWStartRestyleLink(UIViewController *vc, CFTimeInterval dur) {
    LYHWRestyleLink *old = objc_getAssociatedObject(vc, @selector(tick:));
    if (old) { [old.link invalidate]; old.link = nil; }
    LYHWRestyleLink *o = [LYHWRestyleLink new];
    o.vc = vc; o.deadline = CACurrentMediaTime() + dur;
    o.link = [CADisplayLink displayLinkWithTarget:o selector:@selector(tick:)];
    [o.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    objc_setAssociatedObject(vc, @selector(tick:), o, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void LYHWRestyleOnAppear(UIViewController *vc) {
    if (!vc.isViewLoaded) return;
    LYHWRestyleVisibleCells(vc.view);
    // 返回转场期间微信会反复重置 cell：在转场的每个阶段都重套一次卡片样式
    LYHWStartRestyleLink(vc, 0.6);

    dispatch_async(dispatch_get_main_queue(), ^{ LYHWRestyleVisibleCells(vc.view); });
}
%hook WCTimeLineViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    LYHWStartTimelineSweep((UIViewController *)self, 1.2);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    LYHWStartTimelineSweep((UIViewController *)self, 0.6);
}
%end

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (self.isViewLoaded) {
        NSInteger k = LYHWPageKind(self.view);
        if (k >= 1 && k <= 4) LYHWRestyleOnAppear((UIViewController *)self);
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (self.isViewLoaded) {
        NSInteger k = LYHWPageKind(self.view);
        if (k >= 1 && k <= 4) LYHWRestyleOnAppear((UIViewController *)self);
    }
}
%end

static void LYHWClearTree(UIView *v) {
    LYHWSetBackgroundIfChanged(v, [UIColor clearColor]);
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


// 群成员网格：原 ZiLiaoSheZhiZiLiaoJieMianChuLi1 的背景清理。
// 真实类名已由 WeChat 8.0.80 dump 确认；这里只清 WCTableView 的底板和细线，
// 不删除头像、文字、按钮等内容视图。
%hook NewChatRoomMemberContainView
- (void)layoutSubviews {
    %orig;
    UITableView *tv = LYHWAncestorTable((UIView *)self);
    if (!LYHWIsGroupRoomInfoTable(tv) || !LYHWCCfg().groupInfoCornerEnabled) return;
    ((UIView *)self).backgroundColor = [UIColor clearColor];
    ((UIView *)self).layer.backgroundColor = nil;
    LYHWClearGroupInfoSurface(tv);
    LYHWClearGroupInfoContent((UIView *)self, 0);
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
    LYHWSetBackgroundIfChanged(cv, LYHWCachedPalette6());
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
