//
//  WPGroupSegmentedControl.m
//

#import "WPGroupSegmentedControl.h"

static const CGFloat kWPGroupBarPaddingH   = 12.0;  // 左右内边距
static const CGFloat kWPGroupItemPaddingH  = 16.0;  // 按钮左右内边距
static const CGFloat kWPGroupItemMinGap    = 8.0;   // 按钮最小间距
static const CGFloat kWPGroupIndicatorLineH = 3.0;  // 线条指示器高度
static const CGFloat kWPGroupIndicatorDot   = 5.0;  // 圆圈指示器直径
static const CGFloat kWPGroupBadgeH         = 16.0;

@interface WPGroupBadgeView : UIView
@property (nonatomic, strong) UILabel *label;
- (void)setCount:(NSInteger)count;
@end

@implementation WPGroupBadgeView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithRed:0xFA/255.0 green:0x51/255.0 blue:0x51/255.0 alpha:1];
        self.layer.cornerRadius = kWPGroupBadgeH / 2.0;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = NO;
        self.hidden = YES;

        _label = [[UILabel alloc] initWithFrame:self.bounds];
        _label.textColor = [UIColor whiteColor];
        _label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_label];
    }
    return self;
}

- (void)setCount:(NSInteger)count {
    if (count <= 0) {
        self.hidden = YES;
        return;
    }
    self.hidden = NO;
    self.label.text = count > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
}

@end

#pragma mark -

@interface WPGroupSegmentedControl () <UIScrollViewDelegate>

@property (nonatomic, strong) NSMutableDictionary<NSString *, WPGroupBadgeView *> *badgeViews;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapGesture;
@property (nonatomic, assign) CGFloat startDragX;
@property (nonatomic, assign) BOOL draggingIndicator;
@property (nonatomic, assign) NSTimeInterval lastTapTime;
@property (nonatomic, assign) NSInteger lastTapIndex;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *textWidthCache;

- (void)setupButtons;
- (void)reloadAppearance;
- (void)refreshBadges;
- (void)handleSettingChanged:(NSNotification *)note;
- (void)updateIndicatorPositionForButton:(UIButton *)btn animated:(BOOL)animated;
- (void)buttonTapped:(UIButton *)sender;
- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;

@end

@implementation WPGroupSegmentedControl

+ (CGFloat)preferredHeight {
    return 44.0;
}

- (instancetype)initWithSegments:(NSArray<NSString *> *)segments {
    if ((self = [super initWithFrame:CGRectMake(0, 0, CGRectGetWidth([UIScreen mainScreen].bounds), [self.class preferredHeight])])) {
        _segments = [segments copy] ?: @[];
        _buttons = [NSMutableArray array];
        _badgeViews = [NSMutableDictionary dictionary];
        _textWidthCache = [NSMutableDictionary dictionary];
        _selectedIndex = 0;

        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_scrollView];

        _indicatorView = [[UIView alloc] initWithFrame:CGRectZero];
        _indicatorView.userInteractionEnabled = YES;
        [_scrollView addSubview:_indicatorView];

        [self setupButtons];
        [self reloadAppearance];

        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
        _panGesture.cancelsTouchesInView = NO;
        _panGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self addGestureRecognizer:_panGesture];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSettingChanged:)
                                                     name:WPGroupBackgroundColorSettingChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSettingChanged:)
                                                     name:WPGroupIndicatorSettingChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSettingChanged:)
                                                     name:WPGroupFontColorSettingChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSettingChanged:)
                                                     name:WPGroupFontSizeSettingChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSettingChanged:)
                                                     name:WPGroupBadgeSettingChanged object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 构建

- (void)setupButtons {
    for (UIButton *b in self.buttons) [b removeFromSuperview];
    [self.buttons removeAllObjects];
    [self.badgeViews removeAllObjects];
    for (UIView *v in self.scrollView.subviews) {
        if (v != self.indicatorView) [v removeFromSuperview];
    }

    WPGroupConfig *cfg = WPGroupConfig.shared;
    for (NSInteger i = 0; i < (NSInteger)self.segments.count; i++) {
        NSString *name = self.segments[i];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = i;
        btn.adjustsImageWhenHighlighted = NO;
        btn.showsTouchWhenHighlighted = NO;
        [btn setTitle:[cfg mappedGroupName:name] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:cfg.groupFontSize weight:UIFontWeightMedium];
        btn.titleLabel.adjustsFontSizeToFitWidth = YES;
        btn.titleLabel.minimumScaleFactor = 0.7;
        btn.titleLabel.textAlignment = NSTextAlignmentCenter;
        [btn addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];

        // 长按：折叠置顶会话 / 快捷修改
        UILongPressGestureRecognizer *longPress =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.45;
        [btn addGestureRecognizer:longPress];

        [self.scrollView addSubview:btn];
        [self.buttons addObject:btn];

        WPGroupBadgeView *badge = [[WPGroupBadgeView alloc] initWithFrame:CGRectZero];
        [self.scrollView addSubview:badge];
        self.badgeViews[name] = badge;
    }
}

- (void)setSegments:(NSArray<NSString *> *)segments {
    if ([_segments isEqualToArray:segments]) return;
    _segments = [segments copy] ?: @[];
    [self setupButtons];
    [self reloadAppearance];
    [self setNeedsLayout];
}

- (void)setBadges:(NSDictionary<NSString *,NSNumber *> *)badges {
    _badges = [badges copy];
    [self refreshBadges];
}

- (void)refreshBadges {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    if (cfg.hideGroupBadge) {
        for (WPGroupBadgeView *v in self.badgeViews.allValues) v.hidden = YES;
        return;
    }
    NSArray *allGroupNames = self.segments;
    // 分组条只显示除"全部"以外的分组？原实现每个分组都有角标，"全部"可单独关
    for (NSInteger i = 0; i < (NSInteger)allGroupNames.count; i++) {
        NSString *name = allGroupNames[i];
        WPGroupBadgeView *badge = self.badgeViews[name];
        NSInteger count = [self.badges[name] integerValue];

        if ([name isEqualToString:WPGroupNameAll] && cfg.hideAllGroupBadge) count = 0;
        if ([name isEqualToString:WPGroupNameService] && cfg.hideServiceAccountBadge) count = 0;

        [badge setCount:count];
    }
    [self setNeedsLayout];
}

#pragma mark - 外观

- (void)reloadAppearance {
    WPGroupConfig *cfg = WPGroupConfig.shared;

    BOOL hideBg = cfg.hideGroupBackgroundColor;
    self.backgroundColor = hideBg ? [UIColor clearColor]
        : ([WPGroupConfig colorFromHexString:[cfg colorStringForKey:@"groupBackgroundColor"
                                                            darkKey:@"groupBackgroundColorDark"]] ?: [UIColor clearColor]);
    self.scrollView.backgroundColor = self.backgroundColor;

    UIColor *sel = [WPGroupConfig colorFromHexString:[cfg colorStringForKey:@"groupFontColor" darkKey:@"groupFontColorDark"]] ?: [UIColor systemGreenColor];
    UIColor *unsel = [WPGroupConfig colorFromHexString:[cfg colorStringForKey:@"groupUnselectedFontColor" darkKey:@"groupUnselectedFontColorDark"]] ?: [UIColor secondaryLabelColor];

    for (UIButton *b in self.buttons) {
        b.titleLabel.font = [UIFont systemFontOfSize:cfg.groupFontSize weight:UIFontWeightMedium];
        [b setTitleColor:unsel forState:UIControlStateNormal];
        [b setTitleColor:sel forState:UIControlStateSelected];
        [b setTitleColor:sel forState:UIControlStateHighlighted];
    }

    UIColor *indicator = [WPGroupConfig colorFromHexString:[cfg colorStringForKey:@"groupIndicatorColor" darkKey:@"groupIndicatorColorDark"]] ?: sel;
    self.indicatorView.backgroundColor = indicator;
    self.indicatorView.hidden = cfg.hideGroupIndicator;
    self.indicatorView.layer.cornerRadius = (cfg.groupIndicatorStyle == 0)
        ? kWPGroupIndicatorLineH / 2.0
        : kWPGroupIndicatorDot / 2.0;

    [self refreshBadges];
    [self setNeedsLayout];
}

- (void)handleSettingChanged:(NSNotification *)note {
    [self reloadAppearance];
}

#pragma mark - 布局

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.buttons.count) return;

    CGFloat barH = CGRectGetHeight(self.bounds);
    CGFloat x = kWPGroupBarPaddingH;
    CGFloat maxH = 0;
    NSMutableArray<NSNumber *> *widths = [NSMutableArray array];

    for (NSInteger i = 0; i < (NSInteger)self.buttons.count; i++) {
        UIButton *btn = self.buttons[i];
        CGSize fitted = [btn sizeThatFits:CGSizeMake(CGFLOAT_MAX, barH)];
        CGFloat w = ceil(fitted.width) + kWPGroupItemPaddingH * 2;
        w = MAX(w, 44.0);
        [widths addObject:@(w)];
        btn.frame = CGRectMake(x, 0, w, barH);
        maxH = MAX(maxH, w);

        // 角标：右上角
        WPGroupBadgeView *badge = self.badgeViews[self.segments[i]];
        if (badge && !badge.hidden) {
            CGSize bs = [badge.label sizeThatFits:CGSizeMake(CGFLOAT_MAX, kWPGroupBadgeH)];
            CGFloat bw = MAX(kWPGroupBadgeH, bs.width + 8);
            badge.frame = CGRectMake(CGRectGetMaxX(btn.frame) - bw + 6, 4, bw, kWPGroupBadgeH);
        }
        x += w + kWPGroupItemMinGap;
    }

    CGFloat contentW = x - kWPGroupItemMinGap + kWPGroupBarPaddingH;
    self.scrollView.contentSize = CGSizeMake(MAX(contentW, CGRectGetWidth(self.bounds)), barH);

    UIButton *cur = self.buttons[MIN(MAX(self.selectedIndex, 0), (NSInteger)self.buttons.count - 1)];
    [self updateIndicatorPositionForButton:cur animated:NO];
}

- (void)updateIndicatorPositionForButton:(UIButton *)btn animated:(BOOL)animated {
    if (!btn) return;
    WPGroupConfig *cfg = WPGroupConfig.shared;
    CGRect frame = btn.frame;
    CGRect target;

    if (cfg.groupIndicatorStyle == 0) {
        // 线条：文字宽度，贴底
        CGSize textSize = [btn.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGRectGetHeight(frame))];
        CGFloat w = MIN(textSize.width, CGRectGetWidth(frame) - 8);
        target = CGRectMake(CGRectGetMidX(frame) - w / 2.0,
                            CGRectGetHeight(self.bounds) - kWPGroupIndicatorLineH - 2.0,
                            w, kWPGroupIndicatorLineH);
    } else {
        // 圆圈：文字下方
        target = CGRectMake(CGRectGetMidX(frame) - kWPGroupIndicatorDot / 2.0,
                            CGRectGetHeight(self.bounds) - kWPGroupIndicatorDot - 4.0,
                            kWPGroupIndicatorDot, kWPGroupIndicatorDot);
    }

    if (animated) {
        [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.indicatorView.frame = target;
        } completion:nil];
    } else {
        self.indicatorView.frame = target;
    }
}

#pragma mark - 交互

- (void)buttonTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (index == self.lastTapIndex && now - self.lastTapTime < 0.3) {
        // 双击：回到列表顶部
        if ([self.delegate respondsToSelector:@selector(segmentedControl:didDoubleTapIndex:)]) {
            [self.delegate segmentedControl:self didDoubleTapIndex:index];
        }
        self.lastTapTime = 0;
        return;
    }
    self.lastTapTime = now;
    self.lastTapIndex = index;

    [self selectSegmentAtIndex:index animated:YES];
}

- (void)selectSegmentAtIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= (NSInteger)self.buttons.count) return;
    BOOL changed = (index != self.selectedIndex);
    self.selectedIndex = index;

    for (UIButton *b in self.buttons) b.selected = (b.tag == index);

    UIButton *btn = self.buttons[index];
    [self updateIndicatorPositionForButton:btn animated:animated];

    // 让选中项尽量居中
    CGFloat targetX = CGRectGetMidX(btn.frame) - CGRectGetWidth(self.scrollView.bounds) / 2.0;
    CGFloat maxX = MAX(0, self.scrollView.contentSize.width - CGRectGetWidth(self.scrollView.bounds));
    targetX = MIN(MAX(0, targetX), maxX);
    [self.scrollView setContentOffset:CGPointMake(targetX, 0) animated:animated];

    if (self.selectionChanged) self.selectionChanged(index);
    if (changed && [self.delegate respondsToSelector:@selector(segmentedControl:didSelectIndex:)]) {
        [self.delegate segmentedControl:self didSelectIndex:index];
    }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint p = [gesture locationInView:self];
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            // 手指落在指示器附近才算拖动
            CGRect hot = CGRectInset(self.indicatorView.frame, -18, -12);
            self.draggingIndicator = CGRectContainsPoint(hot, p);
            self.startDragX = p.x;
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!self.draggingIndicator) break;
            CGFloat dx = p.x - self.startDragX;
            CGRect f = self.indicatorView.frame;
            self.indicatorView.frame = CGRectOffset(f, dx, 0);
            self.startDragX = p.x;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!self.draggingIndicator) break;
            self.draggingIndicator = NO;
            // 吸到最近的分组
            CGFloat cx = CGRectGetMidX(self.indicatorView.frame);
            NSInteger nearest = self.selectedIndex;
            CGFloat best = CGFLOAT_MAX;
            for (NSInteger i = 0; i < (NSInteger)self.buttons.count; i++) {
                CGFloat d = fabs(CGRectGetMidX(self.buttons[i].frame) - cx);
                if (d < best) { best = d; nearest = i; }
            }
            [self selectSegmentAtIndex:nearest animated:YES];
            break;
        }
        default: break;
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIButton *btn = (UIButton *)gesture.view;
    if (![btn isKindOfClass:[UIButton class]]) return;

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    if ([self.delegate respondsToSelector:@selector(segmentedControl:didLongPressIndex:)]) {
        [self.delegate segmentedControl:self didLongPressIndex:btn.tag];
        return;
    }

    // 默认行为：切换"折叠置顶会话"（与插件长按分组一致）
    WPGroupConfig *cfg = WPGroupConfig.shared;
    cfg.disableFoldTopSession = !cfg.disableFoldTopSession;
    [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupFoldTopSessionSettingChanged object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupListChanged object:nil];
}

#pragma mark - 手势代理

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return other == self.scrollView.panGestureRecognizer;
}

@end
