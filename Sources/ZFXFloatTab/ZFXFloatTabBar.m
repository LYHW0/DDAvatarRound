//
//  ZFXFloatTabBar.m
//

#import "ZFXFloatTabBar.h"
#import "ZFXFloatTabSettings.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#import <QuartzCore/QuartzCore.h>

// 图标兜底（拿不到原生图标时使用）
static NSArray<NSString *> *ZFXFallbackTitles(void) {
    return @[@"微信", @"通讯录", @"发现", @"我"];
}

static NSUInteger ZFXSelectedIndexOfTabBar(id bar) {
    @try {
        id items = [bar valueForKey:@"items"];
        id sel   = [bar valueForKey:@"selectedItem"];
        if ([items isKindOfClass:[NSArray class]] && sel) {
            NSUInteger i = [(NSArray *)items indexOfObject:sel];
            if (i != NSNotFound) return i;
        }
    } @catch (__unused NSException *e) {}
    return 0;
}

static id ZFXTabBarItemViews(id bar) {
    @try {
        SEL s = NSSelectorFromString(@"tabBarItemViews");
        if ([bar respondsToSelector:s]) {
            NSArray *(*fn)(id, SEL) = (void *)objc_msgSend;
            id v = fn(bar, s);
            if ([v isKindOfClass:[NSArray class]]) return v;
            if ([v isKindOfClass:[NSSet class]]) return [(NSSet *)v allObjects];
        }
    } @catch (__unused NSException *e) {}
    // 退路：直接找 UITabBarButton
    NSMutableArray *out = [NSMutableArray array];
    if ([bar isKindOfClass:[UIView class]]) {
        for (UIView *v in [(UIView *)bar subviews]) {
            NSString *cn = NSStringFromClass([v class]);
            if ([cn containsString:@"TabBarButton"] || [cn containsString:@"ItemView"]) {
                [out addObject:v];
            }
        }
    }
    return out;
}

static UIImageView *ZFXFindImageView(UIView *root) {
    if ([root isKindOfClass:[UIImageView class]]) return (UIImageView *)root;
    for (UIView *v in root.subviews) {
        UIImageView *r = ZFXFindImageView(v);
        if (r) return r;
    }
    return nil;
}

static UILabel *ZFXFindLabel(UIView *root) {
    if ([root isKindOfClass:[UILabel class]]) return (UILabel *)root;
    for (UIView *v in root.subviews) {
        UILabel *r = ZFXFindLabel(v);
        if (r) return r;
    }
    return nil;
}

static UIColor *bgTintForConfig(ZFXConfig cfg);

static void ZFXHaptic(void) {
    UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [g prepare];
    [g impactOccurred];
}

#pragma mark - 按钮

@implementation ZFXFloatingItemButton

@synthesize selectedState = _selectedState;

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];

        _selectionPill = [[UIView alloc] initWithFrame:CGRectZero];
        _selectionPill.userInteractionEnabled = NO;
        _selectionPill.alpha = 0.0;
        if (@available(iOS 13.0, *)) _selectionPill.layer.cornerCurve = kCACornerCurveContinuous;
        [self addSubview:_selectionPill];

        _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.userInteractionEnabled = NO;
        [self addSubview:_iconView];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.userInteractionEnabled = NO;
        [self addSubview:_titleLabel];

        _badgeDot = [[UIView alloc] initWithFrame:CGRectZero];
        _badgeDot.backgroundColor = [UIColor systemRedColor];
        _badgeDot.layer.cornerRadius = 3.0;
        _badgeDot.hidden = YES;
        _badgeDot.userInteractionEnabled = NO;
        [self addSubview:_badgeDot];

        _badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _badgeLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.backgroundColor = [UIColor systemRedColor];
        _badgeLabel.clipsToBounds = YES;
        _badgeLabel.hidden = YES;
        _badgeLabel.userInteractionEnabled = NO;
        [self addSubview:_badgeLabel];
    }
    return self;
}

- (void)applyConfig:(ZFXConfig)cfg {
    self.titleLabel.hidden = cfg.hideText;
    self.badgeDot.hidden   = cfg.hideDot;
    self.badgeLabel.hidden = cfg.hideBadge;

    CGFloat fontSize = 10.0;
    self.titleLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium];
    UIColor *buttonColor = [cfg.btnColor isKindOfClass:[UIColor class]] ? cfg.btnColor : [UIColor colorWithWhite:0.18 alpha:1.0];
    self.titleLabel.textColor = buttonColor;
    self.iconView.tintColor = buttonColor;

    self.selectionPill.backgroundColor = [buttonColor colorWithAlphaComponent:0.12];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect b = self.bounds;
    BOOL showText = !self.titleLabel.hidden;
    CGFloat iconSide = MIN(b.size.height * (showText ? 0.44 : 0.52), 24.0);

    if (showText) {
        self.iconView.frame = CGRectMake((b.size.width - iconSide) / 2.0,
                                         b.size.height * 0.16,
                                         iconSide, iconSide);
        self.titleLabel.frame = CGRectMake(0,
                                           CGRectGetMaxY(self.iconView.frame) + 1.0,
                                           b.size.width,
                                           b.size.height - CGRectGetMaxY(self.iconView.frame) - 2.0);
    } else {
        self.iconView.frame = CGRectMake((b.size.width - iconSide) / 2.0,
                                         (b.size.height - iconSide) / 2.0,
                                         iconSide, iconSide);
        self.titleLabel.frame = CGRectZero;
    }

    CGFloat pillW = MIN(b.size.width - 4.0, 56.0);
    CGFloat pillH = b.size.height - 8.0;
    self.selectionPill.frame = CGRectMake((b.size.width - pillW) / 2.0, 4.0, pillW, pillH);
    self.selectionPill.layer.cornerRadius = pillH / 2.0;

    CGFloat dotSide = 6.0;
    self.badgeDot.frame = CGRectMake(CGRectGetMaxX(self.iconView.frame) + 1.0,
                                     CGRectGetMinY(self.iconView.frame) - 1.0,
                                     dotSide, dotSide);
    self.badgeDot.layer.cornerRadius = dotSide / 2.0;

    self.badgeLabel.frame = CGRectMake(CGRectGetMaxX(self.iconView.frame) - 2.0,
                                       CGRectGetMinY(self.iconView.frame) - 3.0,
                                       14.0, 12.0);
    self.badgeLabel.layer.cornerRadius = 6.0;
}

- (void)setSelectedState:(BOOL)selected {
    [self setSelectedState:selected animated:NO anim:0];
}

- (void)setSelectedState:(BOOL)selected animated:(BOOL)animated anim:(NSInteger)anim {
    _selectedState = selected;

    void (^apply)(void) = ^{
        self.selectionPill.alpha = selected ? 1.0 : 0.0;
        self.titleLabel.alpha    = selected ? 1.0 : 0.72;
        self.iconView.alpha      = selected ? 1.0 : 0.72;
    };

    if (!animated || anim <= 0) {
        apply();
        return;
    }

    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:apply completion:nil];

    // 图标动效：1 弹跳 2 脉冲 3 摇摆 4 淡入滑动 5 弹簧
    if (!selected) return;
    CALayer *layer = self.iconView.layer;
    [layer removeAllAnimations];

    switch (anim) {
        case 1: {   // 弹跳
            CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            a.values   = @[@1.0, @1.28, @0.92, @1.06, @1.0];
            a.keyTimes = @[@0.0, @0.28, @0.55, @0.78, @1.0];
            a.duration = 0.42;
            [layer addAnimation:a forKey:@"zfx.bounce"];
            break;
        }
        case 2: {   // 脉冲
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            a.fromValue = @0.84; a.toValue = @1.0;
            a.duration = 0.3;
            a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            [layer addAnimation:a forKey:@"zfx.pulse"];
            break;
        }
        case 3: {   // 摇摆
            CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
            a.values = @[@0.0, @(-0.22), @0.18, @(-0.10), @0.0];
            a.duration = 0.45;
            [layer addAnimation:a forKey:@"zfx.wobble"];
            break;
        }
        case 4: {   // 淡入上滑
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
            a.fromValue = @6.0; a.toValue = @0.0;
            a.duration = 0.26;
            [layer addAnimation:a forKey:@"zfx.slideup"];
            CABasicAnimation *o = [CABasicAnimation animationWithKeyPath:@"opacity"];
            o.fromValue = @0.3; o.toValue = @1.0;
            o.duration = 0.26;
            [layer addAnimation:o forKey:@"zfx.fade"];
            break;
        }
        case 5: {   // 弹簧
            CASpringAnimation *a = [CASpringAnimation animationWithKeyPath:@"transform.scale"];
            a.fromValue = @0.80; a.toValue = @1.0;
            a.damping = 9.0; a.stiffness = 210.0; a.mass = 0.7;
            a.duration = a.settlingDuration;
            [layer addAnimation:a forKey:@"zfx.spring"];
            break;
        }
        default: break;
    }
}

@end

#pragma mark - 底栏本体

@interface ZFXFloatingBarView ()
@property (nonatomic, assign) BOOL adjusting;
@property (nonatomic, assign) CGPoint gestureStartPoint;
@property (nonatomic, assign) CGFloat startWidthOffset;
@property (nonatomic, assign) CGFloat startYOffset;
@end

@implementation ZFXFloatingBarView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.layer.masksToBounds = NO;

        _glowView = [[UIView alloc] initWithFrame:CGRectZero];
        _glowView.userInteractionEnabled = NO;
        _glowView.backgroundColor = [UIColor clearColor];
        _glowView.layer.shadowOffset = CGSizeMake(0, 6);
        _glowView.layer.shadowOpacity = 0.0;
        _glowView.layer.shadowRadius = 18.0;
        [self addSubview:_glowView];

        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
        _effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
        _effectView.userInteractionEnabled = NO;
        _effectView.clipsToBounds = YES;
        [self addSubview:_effectView];

        _tintView = [[UIView alloc] initWithFrame:CGRectZero];
        _tintView.userInteractionEnabled = NO;
        [self addSubview:_tintView];

        _highlightLayer = [CAGradientLayer layer];
        _highlightLayer.colors = @[(id)[UIColor colorWithWhite:1.0 alpha:0.30].CGColor,
                                   (id)[UIColor colorWithWhite:1.0 alpha:0.04].CGColor,
                                   (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor];
        _highlightLayer.locations = @[@0.0, @0.42, @1.0];
        _highlightLayer.startPoint = CGPointMake(0.5, 0.0);
        _highlightLayer.endPoint   = CGPointMake(0.5, 1.0);
        [self.layer addSublayer:_highlightLayer];

        _borderView = [[UIView alloc] initWithFrame:CGRectZero];
        _borderView.userInteractionEnabled = NO;
        _borderView.backgroundColor = [UIColor clearColor];
        _borderView.layer.borderWidth = 0.6;
        _borderView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
        [self addSubview:_borderView];

        _itemsContainer = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:_itemsContainer];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        pan.delegate = self;
        pan.cancelsTouchesInView = NO;
        [_itemsContainer addGestureRecognizer:pan];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(zfx_handleTap:)];
        tap.delegate = self;
        tap.cancelsTouchesInView = NO;
        [self addGestureRecognizer:tap];

        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        lp.minimumPressDuration = 0.45;
        lp.delegate = self;
        lp.cancelsTouchesInView = NO;
        [_itemsContainer addGestureRecognizer:lp];
    }
    return self;
}

#pragma mark 数据来源

- (void)reloadFromHostTabBar {
    NSArray *native = ZFXTabBarItemViews(self.hostTabBar);
    NSArray *titles = ZFXFallbackTitles();

    NSUInteger count = native.count ?: titles.count;
    if (count > 5) count = 5;

    // 数量没变就只刷新图标/文字，避免每次 layout 都重建视图
    if (self.itemButtons.count == count && count > 0) {
        for (NSUInteger i = 0; i < count; i++) {
            ZFXFloatingItemButton *b = self.itemButtons[i];
            UIImage *icon = nil;
            NSString *text = nil;
            if (i < native.count) {
                UIView *nv = native[i];
                UIImageView *iv = ZFXFindImageView(nv);
                icon = iv.image ?: iv.highlightedImage;
                UILabel *lb = ZFXFindLabel(nv);
                text = lb.text;
            }
            if (text.length == 0) text = titles[i];
            if (text.length) b.titleLabel.text = text;
            if (icon) b.iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        return;
    }

    for (ZFXFloatingItemButton *b in self.itemButtons) [b removeFromSuperview];
    NSMutableArray *buttons = [NSMutableArray array];

    for (NSUInteger i = 0; i < count; i++) {
        ZFXFloatingItemButton *b = [[ZFXFloatingItemButton alloc] initWithFrame:CGRectZero];
        b.index = (NSInteger)i;
        [b addTarget:self action:@selector(tapItem:) forControlEvents:UIControlEventTouchUpInside];

        UIImage *icon = nil;
        NSString *text = nil;
        if (i < native.count) {
            UIView *nv = native[i];
            UIImageView *iv = ZFXFindImageView(nv);
            icon = iv.image ?: iv.highlightedImage;
            UILabel *lb = ZFXFindLabel(nv);
            text = lb.text;
        }
        if (text.length == 0) text = titles[i];
        b.titleLabel.text = text;
        b.iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

        [_itemsContainer addSubview:b];
        [buttons addObject:b];
    }
    self.itemButtons = buttons;
}

#pragma mark 布局

- (CGRect)resolvedFrameForSuperview:(UIView *)superview config:(ZFXConfig)cfg {
    // superview 就是原生 MMTabBar，坐标一律按它的本地坐标系来算
    CGFloat W = superview.bounds.size.width;
    if (W <= 0) return CGRectZero;

    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) safeBottom = superview.safeAreaInsets.bottom;
    (void)safeBottom;

    CGFloat contentH = 49.0;                                 // 原生内容区高度
    CGFloat barH = contentH + cfg.heightOffset;              // 原生 49 + 高度微调
    barH = MAX(38.0, MIN(96.0, barH));

    CGFloat width = W - 24.0 + cfg.widthOffset;              // 左右各 12 缩进 + 宽度微调
    width = MAX(W * 0.55, MIN(W - 8.0, width));

    CGFloat x = (W - width) / 2.0;
    CGFloat y = (contentH - barH) / 2.0 - cfg.yOffset;       // 上下微调：正数上移
    return CGRectMake(x, y, width, barH);
}

- (void)applyConfigAndLayout:(ZFXConfig)cfg {
    UIView *sv = self.superview;
    if (!sv) return;

    CGRect f = [self resolvedFrameForSuperview:sv config:cfg];
    if (!CGRectEqualToRect(self.frame, f)) self.frame = f;

    CGFloat h = f.size.height;
    CGFloat w = f.size.width;
    CGFloat radius = h / 2.0 + cfg.radiusOffset;
    radius = MAX(6.0, MIN(h / 2.0 + 24.0, radius));

    self.alpha = cfg.alpha;

    // 背景模糊：初始/液态/组合开启，自定义样式用纯色
    BOOL useBlur = (cfg.style != ZFXStyleCustom);
    self.effectView.hidden = !useBlur;
    self.effectView.frame = self.bounds;
    self.effectView.layer.cornerRadius = radius;
    self.effectView.clipsToBounds = YES;

    self.tintView.frame = self.bounds;
    self.tintView.layer.cornerRadius = radius;
    self.tintView.clipsToBounds = YES;

    self.borderView.frame = self.bounds;
    self.borderView.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) self.borderView.layer.cornerCurve = kCACornerCurveContinuous;

    self.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) self.layer.cornerCurve = kCACornerCurveContinuous;

    UIColor *buttonColor = [cfg.btnColor isKindOfClass:[UIColor class]] ? cfg.btnColor : [UIColor colorWithWhite:0.18 alpha:1.0];
    UIColor *bgTint = nil;
    CGFloat bgAlpha = 0.0;
    UIColor *border = [UIColor colorWithWhite:1.0 alpha:0.22];
    CGFloat glowOpacity = 0.0;
    UIColor *glowColor = [UIColor blackColor];
    CGFloat highlightAlpha = 0.0;

    switch (cfg.style) {
        case ZFXStyleInitial:
            bgTint = nil; bgAlpha = 0.0;
            border = [UIColor colorWithWhite:1.0 alpha:0.18];
            break;
        case ZFXStyleLiquid: {
            UIColor *liquid = [UIColor colorWithWhite:1.0 alpha:1.0];
            bgTint = [liquid colorWithAlphaComponent:1.0];
            bgAlpha = 0.14;
            border = [UIColor colorWithWhite:1.0 alpha:0.42];
            highlightAlpha = 1.0;
            glowOpacity = 0.18;
            glowColor = [UIColor colorWithWhite:1.0 alpha:1.0];
            break;
        }
        case ZFXStyleCombined:
            bgTint = bgTintForConfig(cfg);
            bgAlpha = 0.42;
            border = [buttonColor colorWithAlphaComponent:0.20];
            highlightAlpha = 0.55;
            glowOpacity = 0.22;
            glowColor = buttonColor;
            break;
        case ZFXStyleCustom:
            bgTint = bgTintForConfig(cfg);
            bgAlpha = 0.96;
            border = [buttonColor colorWithAlphaComponent:0.28];
            highlightAlpha = 0.0;
            break;
    }

    self.tintView.backgroundColor = bgTint ? [bgTint colorWithAlphaComponent:bgAlpha] : [UIColor clearColor];
    self.borderView.layer.borderColor = border.CGColor;
    self.borderView.layer.borderWidth = (cfg.style == ZFXStyleInitial) ? 0.5 : 0.8;

    self.highlightLayer.frame = self.bounds;
    self.highlightLayer.cornerRadius = radius;
    self.highlightLayer.masksToBounds = YES;
    self.highlightLayer.opacity = highlightAlpha;

    // 立体效果：投影
    if (cfg.stereo) {
        self.layer.shadowColor  = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.22;
        self.layer.shadowRadius = 16.0;
        self.layer.shadowOffset = CGSizeMake(0, 8);
        self.layer.masksToBounds = NO;
    } else {
        self.layer.shadowOpacity = 0.0;
    }

    // 遮罩发光
    self.glowView.frame = self.bounds;
    self.glowView.layer.cornerRadius = radius;
    self.glowView.layer.shadowColor = glowColor.CGColor;
    self.glowView.layer.shadowOpacity = (cfg.maskGlow ? MAX(glowOpacity, 0.35) : glowOpacity);
    self.glowView.layer.shadowRadius = cfg.maskGlow ? 22.0 : 18.0;
    self.glowView.layer.shadowOffset = CGSizeZero;
    self.glowView.backgroundColor = [UIColor clearColor];

    // 按钮
    CGFloat itemW = w / MAX(1.0, (CGFloat)self.itemButtons.count);
    CGFloat itemH = h;
    for (ZFXFloatingItemButton *b in self.itemButtons) {
        b.frame = CGRectMake(itemW * b.index, 0, itemW, itemH);
        [b applyConfig:cfg];
    }

    self.itemsContainer.frame = self.bounds;
    self.itemsContainer.layer.cornerRadius = radius;
    self.itemsContainer.clipsToBounds = NO;

    [self syncSelectedIndex:(NSInteger)ZFXSelectedIndexOfTabBar(self.hostTabBar) animated:NO];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.glowView.frame = self.bounds;
    self.effectView.frame = self.bounds;
    self.tintView.frame = self.bounds;
    self.borderView.frame = self.bounds;
    self.highlightLayer.frame = self.bounds;
    self.itemsContainer.frame = self.bounds;
}

- (void)syncSelectedIndex:(NSInteger)index animated:(BOOL)animated {
    ZFXConfig cfg = [ZFXPrefs config];
    for (ZFXFloatingItemButton *b in self.itemButtons) {
        [b setSelectedState:(b.index == index) animated:animated anim:cfg.iconAnim];
    }
}

#pragma mark 交互

static id ZFXFindSelector(UIViewController *vc, SEL sel, int depth) {
    if (!vc || depth > 6) return nil;
    if ([vc respondsToSelector:sel]) return vc;
    for (UIViewController *c in vc.childViewControllers) { id r = ZFXFindSelector(c, sel, depth + 1); if (r) return r; }
    return nil;
}

static id ZFXTabOwner(UIView *bar, SEL sel) {
    for (UIResponder *r = bar; r; r = r.nextResponder)
        if ([r isKindOfClass:[UIViewController class]] && [r respondsToSelector:sel]) return r;
    return ZFXFindSelector(bar.window.rootViewController, sel, 0);
}

static void ZFXSelectTab(UIView *bar, NSInteger idx) {
    SEL s1 = NSSelectorFromString(@"didSingleTapTabBarItemAtIndex:wasSelected:");
    SEL s2 = NSSelectorFromString(@"handleUserSelectionAtIndex:");
    SEL s3 = @selector(setSelectedIndex:);
    id owner = ZFXTabOwner(bar, s1);
    if (owner) {
        BOOL was = NO;
        @try { was = [[owner valueForKey:@"selectedIndex"] integerValue] == idx; } @catch (__unused id e) {}
        ((void (*)(id, SEL, unsigned long long, BOOL))objc_msgSend)(owner, s1, (unsigned long long)idx, was);
        return;
    }
    owner = ZFXTabOwner(bar, s2);
    if (owner) { ((void (*)(id, SEL, unsigned long long))objc_msgSend)(owner, s2, (unsigned long long)idx); return; }
    owner = ZFXTabOwner(bar, s3);
    if (owner) {
        ((void (*)(id, SEL, unsigned long long))objc_msgSend)(owner, s3, (unsigned long long)idx);
        if ([owner isKindOfClass:[UITabBarController class]]) {
            UITabBarController *t = owner;
            if ([t.delegate respondsToSelector:@selector(tabBarController:didSelectViewController:)] && t.selectedViewController)
                [t.delegate tabBarController:t didSelectViewController:t.selectedViewController];
        }
        return;
    }
    SEL sel = NSSelectorFromString(@"selectIndex:");
    if ([bar respondsToSelector:sel]) ((void (*)(id, SEL, long long))objc_msgSend)(bar, sel, (long long)idx);
}

- (void)zfx_performSelectIndex:(NSInteger)idx {
    CFTimeInterval now = CACurrentMediaTime();
    static CFTimeInterval last = 0; static NSInteger lastIdx = -1;
    if (idx == lastIdx && now - last < 0.25) return;
    last = now; lastIdx = idx;
    ZFXHaptic();
    @try { ZFXSelectTab((UIView *)self.hostTabBar, idx); } @catch (__unused id e) {}
    [self syncSelectedIndex:idx animated:YES];
}

- (void)tapItem:(ZFXFloatingItemButton *)sender {
    [self zfx_performSelectIndex:sender.index];
}

- (void)zfx_handleTap:(UITapGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateEnded) return;
    NSUInteger n = self.itemButtons.count;
    if (!n) return;
    CGPoint p = [g locationInView:self];
    NSInteger idx = (NSInteger)floor(p.x / (self.bounds.size.width / (CGFloat)n));
    idx = MAX(0, MIN((NSInteger)n - 1, idx));
    [self zfx_performSelectIndex:idx];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;

    ZFXConfig cfg = [ZFXPrefs config];
    CGPoint p = [g locationInView:self.itemsContainer];
    NSInteger idx = 0;
    if (self.itemButtons.count > 0) {
        CGFloat itemW = self.bounds.size.width / (CGFloat)self.itemButtons.count;
        idx = (NSInteger)floor(p.x / MAX(itemW, 1.0));
        idx = MAX(0, MIN((NSInteger)self.itemButtons.count - 1, idx));
    }

    ZFXHaptic();

    // 长按第二个按钮 → 进入位置/大小调节
    if (idx == 1) {
        self.adjusting = YES;
        self.gestureStartPoint = p;
        self.startWidthOffset = cfg.widthOffset;
        self.startYOffset = cfg.yOffset;
        self.transform = CGAffineTransformMakeScale(1.04, 1.04);
        [UIView animateWithDuration:0.15 animations:^{
            self.transform = CGAffineTransformMakeScale(1.04, 1.04);
        }];
    }

    if (cfg.longPopup && idx != 1) {
        [[ZFXFloatTabManager shared] presentQuickSettings];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    if (!self.adjusting) return;

    CGPoint p = [g locationInView:self.itemsContainer];
    CGFloat dx = p.x - self.gestureStartPoint.x;
    CGFloat dy = p.y - self.gestureStartPoint.y;

    if (g.state == UIGestureRecognizerStateChanged) {
        NSInteger w = (NSInteger)lround(self.startWidthOffset + dx * 0.6);
        NSInteger y = (NSInteger)lround(self.startYOffset - dy * 0.4);
        w = MAX(-50, MIN(50, w));
        y = MAX(-40, MIN(40, y));

        [ZFXPrefs setInt:w forKey:ZFXKeyWidth];
        [ZFXPrefs setInt:y forKey:ZFXKeyY];

        ZFXConfig cfg = [ZFXPrefs config];
        [self applyConfigAndLayout:cfg];
        [[NSNotificationCenter defaultCenter] postNotificationName:ZFXSettingsChangedNotification object:nil];
    } else if (g.state == UIGestureRecognizerStateEnded ||
               g.state == UIGestureRecognizerStateCancelled ||
               g.state == UIGestureRecognizerStateFailed) {
        self.adjusting = NO;
        [UIView animateWithDuration:0.18 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)o {
    return YES;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    return v ?: (CGRectContainsPoint(self.bounds, point) ? self : nil);
}

@end

#pragma mark - 工具

static UIColor *bgTintForConfig(ZFXConfig cfg) {
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark);
    }
    UIColor *candidate = dark ? cfg.bgDark : cfg.bgLight;
    return [candidate isKindOfClass:[UIColor class]] ? candidate : (dark ? [UIColor colorWithWhite:0.11 alpha:1.0] : [UIColor colorWithWhite:0.97 alpha:1.0]);
}

#pragma mark - 调度

@interface ZFXFloatTabManager ()
@property (nonatomic, strong) NSMutableArray<ZFXFloatingBarView *> *bars;
@property (nonatomic, strong) UIView *maskView;
@property (nonatomic, strong) UIVisualEffectView *maskBlur;
@property (nonatomic, strong) CAGradientLayer *maskGradient;
@property (nonatomic, assign) BOOL installed;
@property (nonatomic, weak)   UIView *maskHost;
@end

@implementation ZFXFloatTabManager

+ (instancetype)shared {
    static ZFXFloatTabManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [ZFXFloatTabManager new]; });
    return m;
}

- (instancetype)init {
    if ((self = [super init])) {
        _bars = [NSMutableArray array];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(settingsChanged:)
                                                     name:ZFXSettingsChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)enabled {
    return [ZFXPrefs config].enabled;
}

- (void)install {
    if (self.installed) return;
    self.installed = YES;
    [ZFXPrefs registerDefaults];
}

- (void)settingsChanged:(NSNotification *)n {
    [self reloadConfig];
}

- (void)reloadConfig {
    ZFXConfig cfg = [ZFXPrefs config];
    for (ZFXFloatingBarView *bar in self.bars) {
        if (!bar.superview) continue;
        [bar reloadFromHostTabBar];
        [bar applyConfigAndLayout:cfg];
    }
    [self updateMaskForConfig:cfg];
}

#pragma mark 接管 MMTabBar

- (ZFXFloatingBarView *)barForTabBar:(id)tabBar {
    for (ZFXFloatingBarView *b in self.bars) {
        if (b.hostTabBar == tabBar) return b;
    }
    return nil;
}

- (void)layoutTabBar:(id)tabBar {
    [self install];

    ZFXConfig cfg = [ZFXPrefs config];
    UIView *bar = (UIView *)tabBar;
    if (![bar isKindOfClass:[UIView class]]) return;

    ZFXFloatingBarView *floating = [self barForTabBar:tabBar];

    if (!cfg.enabled) {
        if (floating) {
            [floating removeFromSuperview];
            [self.bars removeObject:floating];
        }
        // 恢复原生：只恢复被悬浮底栏隐藏过的视图，不碰微信自己隐藏的视图
        for (UIView *v in bar.subviews) {
            NSArray *saved = objc_getAssociatedObject(v, "zfx.saved");
            if (!saved) continue;
            v.alpha = [saved[0] doubleValue];
            v.userInteractionEnabled = [saved[1] boolValue];
            objc_setAssociatedObject(v, "zfx.saved", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [self hideMask];
        return;
    }

    // 原生内容隐藏
    for (UIView *v in bar.subviews) {
        if ([v isKindOfClass:[ZFXFloatingBarView class]]) continue;
        if (!objc_getAssociatedObject(v, "zfx.saved"))
            objc_setAssociatedObject(v, "zfx.saved", @[@(v.alpha), @(v.userInteractionEnabled)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        v.alpha = 0.0;
        v.userInteractionEnabled = NO;
    }
    bar.backgroundColor = [UIColor clearColor];
    bar.clipsToBounds = NO;
    bar.layer.mask = nil;
    for (UIGestureRecognizer *g in bar.gestureRecognizers) g.cancelsTouchesInView = NO;
    if ([bar respondsToSelector:@selector(setBackgroundImage:)]) {
        [(UITabBar *)bar setBackgroundImage:[UIImage new]];
    }

    if (!floating) {
        floating = [[ZFXFloatingBarView alloc] initWithFrame:CGRectZero];
        floating.hostTabBar = tabBar;
        [bar addSubview:floating];
        [self.bars addObject:floating];
        [floating reloadFromHostTabBar];
    }

    [floating reloadFromHostTabBar];
    [floating applyConfigAndLayout:cfg];
    [self updateMaskForConfig:cfg];
}

- (void)tabBar:(id)tabBar didSelectIndex:(NSInteger)index {
    ZFXFloatingBarView *bar = [self barForTabBar:tabBar];
    [bar syncSelectedIndex:index animated:YES];
}

- (BOOL)shouldSuppressNativeAppearance {
    return [self enabled];
}

- (UIView *)hitTestExtensionForTabBar:(id)tabBar point:(CGPoint)point event:(UIEvent *)event {
    if (![self enabled]) return nil;
    ZFXFloatingBarView *bar = [self barForTabBar:tabBar];
    if (!bar) return nil;

    CGRect expanded = CGRectInset(bar.frame, 0, -15.0);
    if (CGRectContainsPoint(expanded, point)) {
        CGPoint local = CGPointMake(point.x - bar.frame.origin.x, point.y - bar.frame.origin.y);
        UIView *hit = [bar hitTest:local withEvent:event];
        return hit ?: bar;
    }
    return nil;
}

#pragma mark 遮罩

- (void)hideMask {
    self.maskView.hidden = YES;
}

- (void)updateMaskForConfig:(ZFXConfig)cfg {
    ZFXFloatingBarView *bar = self.bars.firstObject;
    if (!bar || !bar.superview) {
        [self hideMask];
        return;
    }

    if (cfg.noMask) {
        [self hideMask];
        return;
    }

    UIView *host = bar.superview;
    if (self.maskView.superview != host) {
        [self.maskView removeFromSuperview];
        self.maskView = [[UIView alloc] initWithFrame:CGRectZero];
        self.maskView.userInteractionEnabled = NO;
        self.maskView.clipsToBounds = YES;

        self.maskBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        self.maskBlur.userInteractionEnabled = NO;
        [self.maskView addSubview:self.maskBlur];

        self.maskGradient = [CAGradientLayer layer];
        self.maskGradient.startPoint = CGPointMake(0.5, 0.0);
        self.maskGradient.endPoint   = CGPointMake(0.5, 1.0);
        [self.maskView.layer addSublayer:self.maskGradient];
    }

    if (self.maskView.superview != host) {
        [host insertSubview:self.maskView belowSubview:bar];
    }

    CGRect barFrame = bar.frame;
    CGFloat W = host.bounds.size.width;
    CGFloat H = host.bounds.size.height;
    CGFloat top = CGRectGetMinY(barFrame) - 24.0;          // 从底栏上方 24pt 开始
    // 遮罩铺满底栏所在的整条区域；开启「遮罩滑动」时随底栏纵向位置实时跟随
    CGFloat maskTop = cfg.maskSlide ? top : (CGRectGetMaxY(barFrame) - 10.0);
    self.maskView.frame = CGRectMake(0, maskTop, W, MAX(0.0, H - maskTop));

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark);
    }
    UIColor *candidate = dark ? cfg.maskDark : cfg.maskLight;
    UIColor *maskColor = [candidate isKindOfClass:[UIColor class]] ? candidate : (dark ? [UIColor blackColor] : [UIColor whiteColor]);

    self.maskBlur.frame = self.maskView.bounds;
    self.maskGradient.frame = self.maskView.bounds;
    self.maskGradient.colors = @[(id)[maskColor colorWithAlphaComponent:0.0].CGColor,
                                 (id)[maskColor colorWithAlphaComponent:0.55].CGColor];
    self.maskGradient.locations = @[@0.0, @1.0];
    self.maskView.alpha = cfg.maskAlpha;
    self.maskView.hidden = NO;
}

#pragma mark 调节卡片

- (void)presentQuickSettings {
    UIWindow *win = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in [(UIWindowScene *)scene windows]) {
                if (w.isKeyWindow) { win = w; break; }
            }
            if (win) break;
        }
    }
    if (!win) win = [UIApplication sharedApplication].keyWindow;

    [ZFXQuickSettingsCard presentInWindow:win];
}

@end
