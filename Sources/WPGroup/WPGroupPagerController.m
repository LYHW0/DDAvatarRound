//
//  WPGroupPagerController.m
//

#import "WPGroupPagerController.h"

@interface WPGroupPagerController () <WPGroupSegmentedControlDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) WPGroupSegmentedControl *segmentedControl;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL isAnimating;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, assign) CGFloat startDragX;
- (void)reloadSegments;
- (void)refreshBadges;
- (void)switchToPage:(NSInteger)index animated:(BOOL)animated;
- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture;
- (void)handleGroupListChanged:(NSNotification *)note;
- (void)handleSessionsReloaded:(NSNotification *)note;
- (void)handleTransitionAnimationSettingChanged:(NSNotification *)note;
- (void)scrollContentViewToTop:(UIView *)view;

@end

@implementation WPGroupPagerController

- (instancetype)initWithDelegate:(id<WPGroupPagerControllerDelegate>)delegate {
    if ((self = [super init])) {
        _delegate = delegate;
        _currentIndex = NSNotFound;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    _contentView = [[UIView alloc] initWithFrame:self.view.bounds];
    _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_contentView];

    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    _panGesture.delegate = self;
    _panGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:_panGesture];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleGroupListChanged:)
                                                 name:WPGroupListChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionsReloaded:)
                                                 name:WPGroupSessionsReloaded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTransitionAnimationSettingChanged:)
                                                 name:WPGroupTransitionAnimationSettingChanged object:nil];

    [self reloadSegments];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.segmentedControl) return;
    CGFloat top = self.view.safeAreaInsets.top;
    self.segmentedControl.frame = CGRectMake(0, top,
                                             CGRectGetWidth(self.view.bounds),
                                             [WPGroupSegmentedControl preferredHeight]);
    self.contentView.frame = CGRectMake(0, CGRectGetMaxY(self.segmentedControl.frame),
                                        CGRectGetWidth(self.view.bounds),
                                        CGRectGetHeight(self.view.bounds) - CGRectGetMaxY(self.segmentedControl.frame));
}

#pragma mark - 分组建构

- (void)reloadSegments {
    NSArray<NSString *> *segments = [WPGroupEngine.shared groupList];
    NSInteger keepIndex = self.currentIndex;
    if (keepIndex == NSNotFound) keepIndex = WPGroupConfig.shared.defaultGroupIndex;
    keepIndex = MIN(MAX(keepIndex, 0), MAX(0, (NSInteger)segments.count - 1));

    [self.segmentedControl removeFromSuperview];

    WPGroupSegmentedControl *control = [[WPGroupSegmentedControl alloc] initWithSegments:segments];
    control.delegate = self;
    __weak typeof(self) weakSelf = self;
    control.selectionChanged = ^(NSInteger index) {
        __strong typeof(weakSelf) self = weakSelf;
        [self switchToPage:index animated:YES];
    };
    [self.view addSubview:control];
    self.segmentedControl = control;

    control.frame = CGRectMake(0, self.view.safeAreaInsets.top,
                               CGRectGetWidth(self.view.bounds),
                               [WPGroupSegmentedControl preferredHeight]);
    control.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    self.contentView.frame = CGRectMake(0, CGRectGetMaxY(control.frame),
                                        CGRectGetWidth(self.view.bounds),
                                        CGRectGetHeight(self.view.bounds) - CGRectGetMaxY(control.frame));

    [self.segmentedControl selectSegmentAtIndex:keepIndex animated:NO];
    [self switchToPage:keepIndex animated:NO];
    [self refreshBadges];
}

- (void)refreshBadges {
    NSDictionary<NSString *, NSNumber *> *badges = nil;
    if ([self.delegate respondsToSelector:@selector(badgesForPagerController:)]) {
        badges = [self.delegate badgesForPagerController:self];
    }
    if (!badges) {
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        for (NSString *name in self.segmentedControl.segments) {
            WPGroupSessionInfo *info = WPGroupEngine.shared.groups[name];
            m[name] = @(info ? info.totalUnread : 0);
        }
        badges = m;
    }
    self.segmentedControl.badges = badges;
}

#pragma mark - 切换

- (void)switchToPage:(NSInteger)index animated:(BOOL)animated {
    NSArray<NSString *> *segments = self.segmentedControl.segments;
    if (index < 0 || index >= (NSInteger)segments.count) return;
    if (index == self.currentIndex) return;

    self.currentIndex = index;
    self.isAnimating = YES;

    NSString *groupName = segments[index];
    [WPGroupEngine.shared selectGroupAtIndex:index];
    [self.segmentedControl selectSegmentAtIndex:index animated:animated];

    if (animated && WPGroupConfig.shared.enableGroupTransitionAnimation) {
        CATransition *anim = [CATransition animation];
        anim.duration = 0.22;
        anim.type = kCATransitionPush;
        CGSize size = self.contentView.bounds.size;
        if (size.width > 0 && size.height > 0) {
            anim.subtype = kCATransitionFromRight;   // 简化：统一从右侧推入
        }
        anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.contentView.layer addAnimation:anim forKey:@"switchAnimation"];
    }

    if ([self.delegate respondsToSelector:@selector(pagerController:didSwitchToGroup:index:)]) {
        [self.delegate pagerController:self didSwitchToGroup:groupName index:index];
    }
    [self refreshBadges];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        weakSelf.isAnimating = NO;
    });
}

#pragma mark - 手势

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    if (!cfg.enableGlobalSwitchGroupGesture && !cfg.enableBottomBarSwitchGroupGesture) return;
    if (self.isAnimating) return;

    CGPoint translation = [gesture translationInView:self.view];
    CGPoint velocity = [gesture velocityInView:self.view];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.startDragX = translation.x;
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat dx = translation.x;
            CGFloat vx = velocity.x;
            BOOL horizontal = fabs(dx) > fabs([gesture translationInView:self.view].y) * 1.5;
            if (!horizontal) break;
            if (dx < -40 || vx < -350) {
                [self switchToPage:self.currentIndex + 1 animated:YES];
            } else if (dx > 40 || vx > 350) {
                [self switchToPage:self.currentIndex - 1 animated:YES];
            }
            break;
        }
        default: break;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer != self.panGesture) return YES;
    CGPoint v = [self.panGesture velocityInView:self.view];
    return fabs(v.x) > fabs(v.y);
}

#pragma mark - 通知

- (void)handleGroupListChanged:(NSNotification *)note {
    NSInteger idx = self.currentIndex;
    [self reloadSegments];
    if (idx != NSNotFound && idx < (NSInteger)self.segmentedControl.segments.count) {
        [self.segmentedControl selectSegmentAtIndex:idx animated:NO];
    }
}

- (void)handleSessionsReloaded:(NSNotification *)note {
    [self refreshBadges];
}

- (void)handleTransitionAnimationSettingChanged:(NSNotification *)note {
    // 播放开关只影响下次切换，无需重建
}

#pragma mark - 分组条代理

- (void)segmentedControl:(WPGroupSegmentedControl *)control didSelectIndex:(NSInteger)index {
    [self switchToPage:index animated:YES];
}

- (void)segmentedControl:(WPGroupSegmentedControl *)control didLongPressIndex:(NSInteger)index {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    cfg.disableFoldTopSession = !cfg.disableFoldTopSession;
    [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupFoldTopSessionSettingChanged object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupListChanged object:nil];
    [self refreshBadges];
}

- (void)segmentedControl:(WPGroupSegmentedControl *)control didDoubleTapIndex:(NSInteger)index {
    // 双击分组：滚动到列表顶部（宿主列表是 UIScrollView 时通用处理）
    [self scrollContentViewToTop:self.contentView];
}

- (void)scrollContentViewToTop:(UIView *)view {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIScrollView class]]) {
            [(UIScrollView *)sub setContentOffset:CGPointZero animated:YES];
        }
        [self scrollContentViewToTop:sub];
    }
}

@end
