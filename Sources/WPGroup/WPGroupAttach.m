//
//  WPGroupAttach.m
//

#import "WPGroupAttach.h"
#import "WPGroupManager.h"
#import "WPGroupSessionListController.h"
#import <objc/runtime.h>

static NSString *WP_autoClassName = @"NewMainFrameViewController";
static NSArray<NSString *> *WP_autoListIvars = nil;
static BOOL WP_autoHooked = NO;

void WPGroupSetAutoHookTarget(NSString *className, NSArray<NSString *> *listIvarNames) {
    if (className.length) WP_autoClassName = [className copy];
    if (listIvarNames.count) WP_autoListIvars = [listIvarNames copy];
}

WPGroupPagerController *WPGroupAttachToViewController(UIViewController *hostVC, UIView *listView) {
    if (!hostVC) return nil;
    if (!WPGroupConfig.shared.enableGroupFilter) return nil;

    // 防止重复挂载
    for (UIViewController *child in hostVC.childViewControllers) {
        if ([child isKindOfClass:[WPGroupPagerController class]]) return (WPGroupPagerController *)child;
    }

    WPGroupPagerController *pager = [[WPGroupManager shared] makePagerController];
    [hostVC addChildViewController:pager];

    UIView *container = hostVC.view;
    CGRect bounds = container.bounds;
    pager.view.frame = bounds;
    pager.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [container addSubview:pager.view];
    [pager didMoveToParentViewController:hostVC];

    // 把宿主的列表挪进 contentView，并缩到分组条下方
    if (listView) {
        CGFloat barH = [WPGroupSegmentedControl preferredHeight] + hostVC.view.safeAreaInsets.top;
        CGRect f = listView.frame;
        listView.frame = CGRectMake(f.origin.x, f.origin.y + barH, f.size.width, f.size.height - barH);
        listView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [pager.contentView addSubview:listView];
    }

    return pager;
}

#pragma mark - 自动挂载

static void WP_swizzle(Class cls, SEL original, SEL replacement) {
    Method m1 = class_getInstanceMethod(cls, original);
    Method m2 = class_getInstanceMethod(cls, replacement);
    if (m1 && m2) method_exchangeImplementations(m1, m2);
}

static void WPGroupAttachOnce(UIViewController *vc, UIView *listView) {
    static NSMutableSet *attached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ attached = [NSMutableSet set]; });
    NSString *key = [NSString stringWithFormat:@"%p", vc];
    if ([attached containsObject:key]) return;
    [attached addObject:key];
    WPGroupAttachToViewController(vc, listView);
}

@interface NSObject (WPGroupAutoHook)
- (void)wpgroup_viewDidAppear:(BOOL)animated;
@end

@implementation NSObject (WPGroupAutoHook)

- (void)wpgroup_viewDidAppear:(BOOL)animated {
    [self wpgroup_viewDidAppear:animated];   // 交换后等价于原实现

    if (![self isKindOfClass:[UIViewController class]]) return;
    UIViewController *vc = (UIViewController *)self;
    if (![NSStringFromClass(vc.class) containsString:WP_autoClassName]) return;
    if (!WPGroupConfig.shared.enableGroupFilter) return;

    // 找列表
    UIView *listView = nil;
    NSArray *ivars = WP_autoListIvars ?: @[@"m_tableView", @"_tableView", @"tableView", @"m_mainTableView"];
    for (NSString *name in ivars) {
        Ivar iv = class_getInstanceVariable(vc.class, name.UTF8String);
        if (iv) {
            id value = object_getIvar(vc, iv);
            if ([value isKindOfClass:[UIView class]]) { listView = value; break; }
        }
    }

    WPGroupAttachOnce(vc, listView);
}

@end

void WPGroupInstallAutoHook(void) {
    if (WP_autoHooked) return;
    WP_autoHooked = YES;

    Class cls = NSClassFromString(@"UIViewController");
    if (!cls) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        WP_swizzle(cls,
                   @selector(viewDidAppear:),
                   @selector(wpgroup_viewDidAppear:));
    });
}
