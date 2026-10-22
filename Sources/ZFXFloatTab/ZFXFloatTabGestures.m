//
//  ZFXFloatTabGestures.m
//

#import "ZFXFloatTabGestures.h"
#import "ZFXFloatTabBar.h"

#pragma mark - 右边缘手势

@implementation WXFloatingTabBarRightEdgePanGesture

- (CGPoint)translationInView:(UIView *)view {
    if (CGPointEqualToPoint(self.zfxFakeTranslation, CGPointZero)) {
        return [super translationInView:view];
    }
    return self.zfxFakeTranslation;
}

- (CGPoint)velocityInView:(UIView *)view {
    if (CGPointEqualToPoint(self.zfxFakeVelocity, CGPointZero)) {
        return [super velocityInView:view];
    }
    return self.zfxFakeVelocity;
}

@end

#pragma mark - 伪造返回手势

@implementation WXFloatingTabBarFakeBackEdgePanGesture

- (UIGestureRecognizerState)state {
    return self.fakeState ?: [super state];
}

- (CGPoint)translationInView:(UIView *)view {
    return self.fakeTranslation;
}

- (CGPoint)velocityInView:(UIView *)view {
    return self.fakeVelocity;
}

- (CGPoint)locationInView:(UIView *)view {
    if (CGPointEqualToPoint(self.fakeLocation, CGPointZero)) {
        return [super locationInView:view];
    }
    return self.fakeLocation;
}

@end

#pragma mark - 代理

@implementation WXFloatingTabBarPopDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return self.nav.viewControllers.count > 1;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)other {
    return NO;
}

@end

#pragma mark - 调度

@interface ZFXEdgeBackController ()
@property (nonatomic, strong) WXFloatingTabBarPopDelegate *popDelegate;
@property (nonatomic, strong) WXFloatingTabBarRightEdgePanGesture *rightEdge;
@property (nonatomic, strong) UIScreenEdgePanGestureRecognizer *leftEdge;
@property (nonatomic, weak) UIView *installedView;
@property (nonatomic, assign) BOOL installed;
@end

@implementation ZFXEdgeBackController

+ (instancetype)shared {
    static ZFXEdgeBackController *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [ZFXEdgeBackController new]; });
    return c;
}

- (instancetype)init {
    if ((self = [super init])) {
        _popDelegate = [WXFloatingTabBarPopDelegate new];
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

- (void)settingsChanged:(NSNotification *)n {
    [self updateEnabledState];
}

- (UIWindow *)keyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in [(UIWindowScene *)scene windows]) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

- (void)updateEnabledState {
    ZFXConfig cfg = [ZFXPrefs config];
    if (!cfg.enabled) {
        [self uninstall];
        return;
    }
    [self installIfNeeded];
}

- (void)installIfNeeded {
    UIView *host = [self keyWindow];
    if (!host) return;
    if (self.installed && self.installedView == host) return;

    [self uninstall];

    self.rightEdge = [[WXFloatingTabBarRightEdgePanGesture alloc] initWithTarget:self
                                                                         action:@selector(handleRightEdge:)];
    self.rightEdge.edges = UIRectEdgeRight;
    self.rightEdge.maximumNumberOfTouches = 1;
    self.rightEdge.delegate = self.popDelegate;
    [host addGestureRecognizer:self.rightEdge];

    self.leftEdge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(handleLeftEdge:)];
    self.leftEdge.edges = UIRectEdgeLeft;
    self.leftEdge.maximumNumberOfTouches = 1;
    self.leftEdge.delegate = self.popDelegate;
    [host addGestureRecognizer:self.leftEdge];

    self.installedView = host;
    self.installed = YES;
}

- (void)uninstall {
    if (self.rightEdge) { [self.rightEdge.view removeGestureRecognizer:self.rightEdge]; self.rightEdge = nil; }
    if (self.leftEdge)  { [self.leftEdge.view removeGestureRecognizer:self.leftEdge];  self.leftEdge = nil; }
    self.installed = NO;
}

- (UINavigationController *)topNavigationController {
    UIViewController *root = [self keyWindow].rootViewController;
    UIViewController *top = root;

    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    if ([top isKindOfClass:[UITabBarController class]]) {
        top = [(UITabBarController *)top selectedViewController];
    }
    if ([top isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)top;
    }
    if (top.navigationController) {
        return top.navigationController;
    }
    // 微信多是嵌套容器，向下找第一层 UINavigationController
    return [self firstNavigationControllerIn:top.view];
}

- (UINavigationController *)firstNavigationControllerIn:(UIView *)view {
    for (UIView *sub in view.subviews) {
        UIResponder *r = sub.nextResponder;
        if ([r isKindOfClass:[UINavigationController class]]) return (UINavigationController *)r;
        UINavigationController *found = [self firstNavigationControllerIn:sub];
        if (found) return found;
    }
    return nil;
}

- (void)handleRightEdge:(WXFloatingTabBarRightEdgePanGesture *)g {
    // 右边缘按住左滑 → 返回
    [self handlePan:g direction:-1];
}

- (void)handleLeftEdge:(UIScreenEdgePanGestureRecognizer *)g {
    [self handlePan:g direction:1];
}

- (void)handlePan:(UIGestureRecognizer *)g direction:(CGFloat)dir {
    UIView *view = g.view;
    CGPoint t = [g locationInView:view];

    switch (g.state) {
        case UIGestureRecognizerStateBegan: {
            self.popDelegate.nav = [self topNavigationController];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            UINavigationController *nav = self.popDelegate.nav;
            if (!nav || nav.viewControllers.count <= 1) break;
            CGPoint translation = [(UIPanGestureRecognizer *)g translationInView:view];
            CGFloat progress = MAX(0.0, MIN(1.0, (translation.x * dir) / MAX(view.bounds.size.width, 1.0)));
            UIView *topView = nav.topViewController.view;
            topView.transform = CGAffineTransformMakeTranslation(translation.x * 0.35 * dir, 0);
            topView.alpha = 1.0 - progress * 0.15;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            UINavigationController *nav = self.popDelegate.nav;
            CGPoint translation = [(UIPanGestureRecognizer *)g translationInView:view];
            CGFloat dx = translation.x * dir;
            BOOL shouldPop = (dx > 70.0);

            UIView *topView = nav.topViewController.view;
            UINavigationController *target = nav;

            if (shouldPop && nav.viewControllers.count > 1) {
                [UIView animateWithDuration:0.2 animations:^{
                    topView.transform = CGAffineTransformMakeTranslation(view.bounds.size.width * dir, 0);
                    topView.alpha = 0.0;
                } completion:^(BOOL finished) {
                    topView.transform = CGAffineTransformIdentity;
                    topView.alpha = 1.0;
                    [target popViewControllerAnimated:NO];
                }];
            } else {
                [UIView animateWithDuration:0.2 animations:^{
                    topView.transform = CGAffineTransformIdentity;
                    topView.alpha = 1.0;
                }];
            }
            (void)t;
            break;
        }
        default:
            break;
    }
}

@end
