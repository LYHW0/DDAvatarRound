//
//  WPGroupEngine.m
//

#import "WPGroupEngine.h"

NSString * const WPGroupNameAll        = @"全部";
NSString * const WPGroupNameChatRoom   = @"群聊";
NSString * const WPGroupNameFriend     = @"好友";
NSString * const WPGroupNameService    = @"服务号";
NSString * const WPGroupNameEnterprise = @"企业号";

/// 微信里服务号盒子的占位会话名
static NSString * const WPBrandServiceBoxToken = @"brandservicesessionholder";
/// 微信里群聊盒子的会话名
static NSString * const WPChatRoomBoxToken = @"chatroom_session_box";

@implementation WPGroupSession

+ (instancetype)sessionWithWxid:(NSString *)wxid name:(NSString *)name {
    WPGroupSession *s = [[WPGroupSession alloc] init];
    s.wxid = wxid ?: @"";
    s.displayName = name ?: s.wxid;
    return s;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[WPGroupSession class]]) return NO;
    return [self.wxid isEqualToString:((WPGroupSession *)object).wxid];
}

- (NSUInteger)hash {
    return self.wxid.hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<WPGroupSession %@ (%@) unread=%ld top=%d>",
            self.displayName, self.wxid, (long)self.unreadCount, self.isTop];
}

@end

@implementation WPGroupSessionInfo

- (instancetype)initWithGroupName:(NSString *)name {
    if ((self = [super init])) {
        _groupName = [name copy];
        _normalSessions = [NSMutableArray array];
        _topSessions = [NSMutableArray array];
        _isAllSessions = [name isEqualToString:WPGroupNameAll];
    }
    return self;
}

- (NSInteger)totalUnread {
    NSInteger n = 0;
    for (WPGroupSession *s in self.normalSessions) n += s.unreadCount;
    for (WPGroupSession *s in self.topSessions) n += s.unreadCount;
    return n;
}

@end

@interface WPGroupEngine ()
- (BOOL)session:(WPGroupSession *)s matchesGroupName:(NSString *)name all:(NSArray<WPGroupSession *> *)all;
@end

@implementation WPGroupEngine

+ (instancetype)shared {
    static WPGroupEngine *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[WPGroupEngine alloc] init]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _groups = [NSMutableDictionary dictionary];
        [self setupDefaultGroups];
    }
    return self;
}

#pragma mark - 分组结构

- (NSArray<NSString *> *)groupList {
    NSArray *list = WPGroupConfig.shared.groupFilterList;
    if (!list.count) list = @[WPGroupNameAll, WPGroupNameChatRoom, WPGroupNameFriend,
                              WPGroupNameService, WPGroupNameEnterprise];
    if (WPGroupConfig.shared.removeServiceAccount) {
        NSMutableArray *m = [list mutableCopy];
        [m removeObject:WPGroupNameService];
        list = m;
    }
    return list;
}

- (void)setupDefaultGroups {
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    for (NSString *name in [self groupList]) {
        groups[name] = [[WPGroupSessionInfo alloc] initWithGroupName:name];
    }
    self.groups = groups;
    self.currentSelectGroup = groups[WPGroupNameAll];
}

- (void)syncGroupsFromConfigIfNeeded {
    NSArray *list = [self groupList];
    NSMutableDictionary *groups = [NSMutableDictionary dictionaryWithCapacity:list.count];
    for (NSString *name in list) {
        WPGroupSessionInfo *info = self.groups[name];
        if (!info) info = [[WPGroupSessionInfo alloc] initWithGroupName:name];
        groups[name] = info;
    }
    self.groups = groups;

    NSString *currentName = self.currentSelectGroup.groupName;
    if (currentName.length && groups[currentName]) {
        self.currentSelectGroup = groups[currentName];
    } else {
        self.currentSelectGroup = groups[WPGroupNameAll] ?: groups.allValues.firstObject;
        if (self.currentSelectGroup) {
            NSUInteger idx = [list indexOfObject:self.currentSelectGroup.groupName];
            if (idx != NSNotFound) WPGroupConfig.shared.defaultGroupIndex = (NSInteger)idx;
        }
    }
}

- (BOOL)selectGroupAtIndex:(NSInteger)index {
    NSArray *list = [self groupList];
    if (index < 0 || index >= (NSInteger)list.count) return NO;
    WPGroupSessionInfo *info = self.groups[list[index]];
    if (!info) return NO;
    self.currentSelectGroup = info;
    WPGroupConfig.shared.defaultGroupIndex = index;
    [self reloadSessions];
    return YES;
}

- (NSString *)currentGroupName {
    return self.currentSelectGroup.groupName ?: WPGroupNameAll;
}

#pragma mark - 刷新

- (void)reloadSessions {
    [self syncGroupsFromConfigIfNeeded];

    NSArray<WPGroupSession *> *all = nil;
    if ([self.provider respondsToSelector:@selector(allSessionsForGroupEngine:)]) {
        all = [self.provider allSessionsForGroupEngine:self] ?: @[];
    }
    if (!all) all = @[];

    for (NSString *name in self.groups.allKeys) {
        WPGroupSessionInfo *info = self.groups[name];
        info.normalSessions = [[self filterSessions:all withGroupName:name needTop:NO] mutableCopy];
        info.topSessions    = [[self filterSessions:all withGroupName:name needTop:YES] mutableCopy];
    }
    self.lastReloadTime = [[NSDate date] timeIntervalSince1970];

    [[NSNotificationCenter defaultCenter] postNotificationName:WPGroupSessionsReloaded object:nil];
}

#pragma mark - 核心过滤

- (BOOL)session:(WPGroupSession *)s matchesGroupName:(NSString *)name
           all:(NSArray<WPGroupSession *> *)all {
    WPGroupConfig *cfg = WPGroupConfig.shared;

    if ([name isEqualToString:WPGroupNameAll]) return YES;

    if ([name isEqualToString:WPGroupNameChatRoom]) {
        return (s.isGroup || [s.wxid isEqualToString:WPChatRoomBoxToken]);
    }

    if ([name isEqualToString:WPGroupNameFriend]) {
        BOOL isRoom = s.isGroup || [s.wxid isEqualToString:WPChatRoomBoxToken];
        BOOL isService = s.isBrandService || s.isInBrandServiceBox
                      || [s.wxid isEqualToString:WPBrandServiceBoxToken];
        return (!isRoom && !isService && !s.isEnterprise);
    }

    if ([name isEqualToString:WPGroupNameService]) {
        return (s.isBrandService || s.isInBrandServiceBox
                || [s.wxid isEqualToString:WPBrandServiceBoxToken]);
    }

    if ([name isEqualToString:WPGroupNameEnterprise]) {
        return (s.isEnterprise
                || [s.wxid hasSuffix:@"@openim"]
                || [s.wxid hasSuffix:@"@ai.openim"]);
    }

    // 自定义分组：按成员表
    NSArray *members = cfg.customGroupList[name];
    if (members) return [members containsObject:s.wxid];

    // 其余当作微信标签分组
    if (s.labelNames.count) return [s.labelNames containsObject:name];

    return NO;
}

- (NSArray<WPGroupSession *> *)filterSessions:(NSArray<WPGroupSession *> *)allSessions
                                withGroupName:(NSString *)groupName
                                      needTop:(BOOL)needTop {
    WPGroupConfig *cfg = WPGroupConfig.shared;
    NSMutableArray<WPGroupSession *> *result = [NSMutableArray array];
    NSMutableSet<NSString *> *seenWxid = [NSMutableSet set];

    for (WPGroupSession *s in allSessions) {
        if (!s.wxid.length) continue;

        // 微信内部占位会话，永远不显示
        if ([s.wxid isEqualToString:WPBrandServiceBoxToken]) continue;

        if (cfg.removeServiceAccount && (s.isBrandService || s.isInBrandServiceBox)) continue;

        // 过滤重复联系人：同一联系人（含其旧会话）只保留一条
        if (cfg.enableFilterDuplicateContacts) {
            if ([seenWxid containsObject:s.wxid]) continue;
        }

        // 隐藏 / 聊天盒子内的会话，系统分组里不显示
        if (s.isHidden || s.isInChatBox) continue;

        if (!needTop && s.isTop) continue;
        if (needTop && !s.isTop) continue;

        if (![self session:s matchesGroupName:groupName all:allSessions]) continue;

        // 置顶过滤：非"全部"分组里，已经被别的分组收走的置顶会话不再重复置顶
        if (needTop && cfg.enableTopFilter
            && ![groupName isEqualToString:WPGroupNameAll]
            && [self isSessionInOtherGroups:s allSessions:allSessions]) {
            continue;
        }

        [seenWxid addObject:s.wxid];
        [result addObject:s];
    }

    // 未读数多的排前面（与微信会话列表一致的稳定顺序，宿主可自行重排）
    [result sortUsingComparator:^NSComparisonResult(WPGroupSession *a, WPGroupSession *b) {
        if (a.unreadCount != b.unreadCount) return a.unreadCount > b.unreadCount ? NSOrderedAscending : NSOrderedDescending;
        return [a.displayName compare:b.displayName];
    }];

    return result;
}

- (BOOL)isSessionInOtherGroups:(WPGroupSession *)session
                   allSessions:(NSArray<WPGroupSession *> *)allSessions {
    if (!session.wxid.length) return NO;
    NSString *current = [self currentGroupName];

    for (NSString *name in self.groups.allKeys) {
        if ([name isEqualToString:current]) continue;
        if ([name isEqualToString:WPGroupNameAll]) continue;
        if ([name isEqualToString:WPGroupNameChatRoom]) continue;
        if ([name isEqualToString:WPGroupNameFriend]) continue;
        if ([name isEqualToString:WPGroupNameService]) continue;
        if ([name isEqualToString:WPGroupNameEnterprise]) continue;

        WPGroupSessionInfo *info = self.groups[name];
        if ([info.topSessions containsObject:session]) return YES;
        if ([info.normalSessions containsObject:session]) return YES;
    }
    return NO;
}

@end
