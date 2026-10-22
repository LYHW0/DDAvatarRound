// 分组功能接入微信主页：分组条 + 行过滤（隐藏不属于当前分组的会话）
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "WPGroupManager.h"
#import "WPGroupSegmentedControl.h"

@interface NewMainFrameViewController : UIViewController
- (id)logicGetSessionAtIndexPath:(id)ip;
- (id)m_tableView;
@end

static id LYMsg(id o, NSString *sel) {
    SEL s = NSSelectorFromString(sel);
    if (!o || ![o respondsToSelector:s]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(o, s);
}
static BOOL LYBool(id o, NSString *sel) {
    SEL s = NSSelectorFromString(sel);
    if (!o || ![o respondsToSelector:s]) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(o, s);
}
static unsigned int LYUInt(id o, NSString *sel) {
    SEL s = NSSelectorFromString(sel);
    if (!o || ![o respondsToSelector:s]) return 0;
    return ((unsigned int (*)(id, SEL))objc_msgSend)(o, s);
}

static WPGroupSession *LYMakeSession(id info) {
    NSString *wxid = LYMsg(info, @"m_nsUserName");
    if (![wxid isKindOfClass:[NSString class]] || !wxid.length) return nil;
    id contact = LYMsg(info, @"m_contact");
    NSString *name = LYMsg(contact, @"getContactDisplayName");
    WPGroupSession *s = [WPGroupSession sessionWithWxid:wxid name:[name isKindOfClass:[NSString class]] ? name : wxid];
    s.isGroup = [wxid hasSuffix:@"@chatroom"];
    s.isBrandService = LYBool(contact, @"isBrandContact") && !s.isGroup;
    s.isEnterprise = [wxid hasSuffix:@"@openim"] || [wxid hasSuffix:@"@ai.openim"];
    s.isTop = LYBool(info, @"m_bIsTop");
    s.unreadCount = LYUInt(info, @"m_uUnReadCount");
    s.rawObject = info;
    return s;
}

@interface LYGroupProvider : NSObject <WPGroupSessionProvider>
@end
@implementation LYGroupProvider
- (NSArray<WPGroupSession *> *)allSessionsForGroupEngine:(WPGroupEngine *)engine {
    NSMutableArray *out = [NSMutableArray array];
    @try {
        Class ctx = NSClassFromString(@"MMContext");
        id c = LYMsg(ctx, @"currentContext") ?: LYMsg(ctx, @"activeUserContext");
        Class mgrCls = NSClassFromString(@"MMNewSessionMgr");
        id mgr = nil;
        if (c && mgrCls && [c respondsToSelector:@selector(getService:)])
            mgr = ((id (*)(id, SEL, Class))objc_msgSend)(c, @selector(getService:), mgrCls);
        NSArray *list = LYMsg(mgr, @"GetSessionInfoList");
        if ([list isKindOfClass:[NSArray class]])
            for (id info in list) { WPGroupSession *s = LYMakeSession(info); if (s) [out addObject:s]; }
    } @catch (__unused id e) {}
    return out;
}
@end

static LYGroupProvider *gProvider;
static NSMutableDictionary *gVisibleCache;

static BOOL LYGroupActive(void) {
    return WPGroupConfig.shared.enableGroupFilter &&
           ![[WPGroupEngine.shared currentGroupName] isEqualToString:WPGroupNameAll];
}

static BOOL LYSessionVisible(NSString *wxid, id info) {
    if (!LYGroupActive()) return YES;
    NSNumber *cached = gVisibleCache[wxid];
    if (cached) return cached.boolValue;
    WPGroupSession *s = LYMakeSession(info);
    if (!s) return YES;
    NSString *g = [WPGroupEngine.shared currentGroupName];
    BOOL ok = [WPGroupEngine.shared filterSessions:@[s] withGroupName:g needTop:s.isTop].count > 0;
    gVisibleCache[wxid] = @(ok);
    return ok;
}

static void LYReloadMain(UIViewController *vc) {
    [gVisibleCache removeAllObjects];
    UITableView *tv = LYMsg(vc, @"m_tableView");
    if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
}

static const void *kLYBarKey = &kLYBarKey;

static void LYInstallBar(UIViewController *vc) {
    WPGroupSegmentedControl *bar = objc_getAssociatedObject(vc, kLYBarKey);
    if (!WPGroupConfig.shared.enableGroupFilter) {
        if (bar) {
            [bar removeFromSuperview];
            objc_setAssociatedObject(vc, kLYBarKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            UIEdgeInsets a = vc.additionalSafeAreaInsets; a.top = 0; vc.additionalSafeAreaInsets = a;
            [WPGroupEngine.shared selectGroupAtIndex:0];
            LYReloadMain(vc);
        }
        return;
    }
    NSArray *list = [WPGroupEngine.shared groupList];
    if (!bar) {
        bar = [[WPGroupSegmentedControl alloc] initWithSegments:list];
        __weak UIViewController *wvc = vc;
        bar.selectionChanged = ^(NSInteger idx) {
            [WPGroupEngine.shared selectGroupAtIndex:idx];
            UIViewController *s = wvc;
            if (s) LYReloadMain(s);
        };
        objc_setAssociatedObject(vc, kLYBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [vc.view addSubview:bar];
        NSInteger idx = WPGroupConfig.shared.defaultGroupIndex;
        if (idx < 0 || idx >= (NSInteger)list.count) idx = 0;
        [WPGroupEngine.shared selectGroupAtIndex:idx];
        [bar selectSegmentAtIndex:idx animated:NO];
        LYReloadMain(vc);
    } else if (![bar.segments isEqualToArray:list]) {
        bar.segments = list;
    }
    CGFloat h = [WPGroupSegmentedControl preferredHeight];
    UIEdgeInsets a = vc.additionalSafeAreaInsets;
    if (fabs(a.top - h) > 0.5) { a.top = h; vc.additionalSafeAreaInsets = a; }
    CGFloat top = vc.view.safeAreaInsets.top - h;
    bar.frame = CGRectMake(0, top, vc.view.bounds.size.width, h);
    [vc.view bringSubviewToFront:bar];
}

%hook NewMainFrameViewController
- (void)viewDidLayoutSubviews {
    %orig;
    LYInstallBar((UIViewController *)self);
}

- (double)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    double h = %orig;
    if (!LYGroupActive()) return h;
    id info = nil;
    @try { info = [self logicGetSessionAtIndexPath:ip]; } @catch (__unused id e) {}
    NSString *wxid = LYMsg(info, @"m_nsUserName");
    if (![wxid isKindOfClass:[NSString class]]) return h;
    return LYSessionVisible(wxid, info) ? h : 0.0;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = %orig;
    BOOL show = YES;
    if (LYGroupActive()) {
        id info = nil;
        @try { info = [self logicGetSessionAtIndexPath:ip]; } @catch (__unused id e) {}
        NSString *wxid = LYMsg(info, @"m_nsUserName");
        if ([wxid isKindOfClass:[NSString class]]) show = LYSessionVisible(wxid, info);
    }
    cell.hidden = !show;
    cell.clipsToBounds = !show;
    return cell;
}
%end

%ctor {
    gVisibleCache = [NSMutableDictionary dictionary];
    gProvider = [LYGroupProvider new];
    [WPGroupManager installWithProvider:gProvider delegate:nil];
    void (^refresh)(NSNotification *) = ^(NSNotification *n) {
        [gVisibleCache removeAllObjects];
        for (UIWindow *w in UIApplication.sharedApplication.windows) [w setNeedsLayout];
    };
    for (NSString *name in @[WPGroupFilterSettingChanged, WPGroupListChanged, WPGroupTopFilterSettingChanged,
                             WPGroupFilterDuplicateContactsSettingChanged])
        [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:[NSOperationQueue mainQueue] usingBlock:refresh];
}
