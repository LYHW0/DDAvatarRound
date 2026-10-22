//
//  WPGroupManager.m
//

#import "WPGroupManager.h"
#import "WPCustomGroupViewController.h"

@interface WPGroupManager () <WPGroupSettingViewControllerDelegate, WPGroupPagerControllerDelegate, WPCustomGroupViewControllerDataSource>
@property (nonatomic, weak) id<WPGroupManagerDelegate> delegate;
@property (nonatomic, weak) WPGroupPagerController *pager;
@end

@implementation WPGroupManager

+ (instancetype)shared {
    static WPGroupManager *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[WPGroupManager alloc] init]; });
    return s;
}

+ (void)installWithProvider:(id<WPGroupSessionProvider>)provider delegate:(id<WPGroupManagerDelegate>)delegate {
    WPGroupManager *m = [self shared];
    m.delegate = delegate;
    WPGroupEngine.shared.provider = provider;
    [WPGroupEngine.shared setupDefaultGroups];
    [WPGroupEngine.shared reloadSessions];
}

- (BOOL)isEnabled {
    return WPGroupConfig.shared.enableGroupFilter;
}

- (void)reload {
    [WPGroupEngine.shared reloadSessions];
    [self.pager refreshBadges];
}

- (NSArray<WPGroupSession *> *)currentTopSessions {
    return WPGroupEngine.shared.currentSelectGroup.topSessions ?: @[];
}

- (NSArray<WPGroupSession *> *)currentNormalSessions {
    return WPGroupEngine.shared.currentSelectGroup.normalSessions ?: @[];
}

#pragma mark - 创建界面

- (WPGroupPagerController *)makePagerController {
    WPGroupPagerController *pager = [[WPGroupPagerController alloc] initWithDelegate:self];
    self.pager = pager;
    return pager;
}

- (UIViewController *)makeSettingsViewController {
    WPGroupSettingViewController *vc = [[WPGroupSettingViewController alloc] init];
    vc.delegate = self;
    return vc;
}

- (void)presentSettingsFrom:(UIViewController *)presenter {
    UIViewController *settings = [self makeSettingsViewController];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    [presenter presentViewController:nav animated:YES completion:nil];
}

#pragma mark - 分组设置代理

- (NSArray<NSString *> *)labelNamesForGroupSettings:(id)controller {
    if ([self.delegate respondsToSelector:@selector(labelNames)]) {
        return [self.delegate labelNames] ?: @[];
    }
    return @[];
}

- (void)groupSettingsRequestRestart:(id)controller {
    if ([self.delegate respondsToSelector:@selector(requestRestart)]) {
        [self.delegate requestRestart];
    }
}

- (void)groupSettingsDidChange:(id)controller {
    [self reload];
    [self.pager reloadSegments];
}

#pragma mark - 分页代理

- (void)pagerController:(WPGroupPagerController *)pager didSwitchToGroup:(NSString *)groupName index:(NSInteger)index {
    [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupFilterSettingChanged object:nil];
}

#pragma mark - 成员选择适配

- (void)customGroup:(WPCustomGroupViewController *)vc
    presentPickerWithSelected:(NSArray<NSString *> *)selected
                   completion:(void (^)(NSArray<NSString *> *wxids))completion {
    if ([self.delegate respondsToSelector:@selector(presentContactPickerFrom:selected:completion:)]) {
        [self.delegate presentContactPickerFrom:vc selected:selected completion:completion];
    }
}

- (NSString *)customGroup:(WPCustomGroupViewController *)vc displayNameForWxid:(NSString *)wxid {
    if ([self.delegate respondsToSelector:@selector(displayNameForWxid:)]) {
        return [self.delegate displayNameForWxid:wxid];
    }
    return wxid;
}

@end
