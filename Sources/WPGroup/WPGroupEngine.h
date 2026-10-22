//
//  WPGroupEngine.h
//  会话分组引擎
//
//  逆向自 WCPulseSessionMgr / WCPulseSessionInfo
//  职责：把宿主给的"全部会话"按当前分组设置切成若干分组，每组分成置顶段 + 普通段
//

#import <Foundation/Foundation.h>
#import "WPGroupConfig.h"

NS_ASSUME_NONNULL_BEGIN

/// 系统内置分组名（顺序与插件一致，也是默认 groupFilterList）
extern NSString * const WPGroupNameAll;        // 全部
extern NSString * const WPGroupNameChatRoom;   // 群聊
extern NSString * const WPGroupNameFriend;     // 好友
extern NSString * const WPGroupNameService;    // 服务号
extern NSString * const WPGroupNameEnterprise; // 企业号

/// 会话的最小描述。宿主把微信会话对象转成它，引擎不依赖任何微信私有类。
@interface WPGroupSession : NSObject

/// 会话唯一标识（微信 wxid / username）
@property (nonatomic, copy) NSString *wxid;
/// 显示名（群名 / 联系人名）
@property (nonatomic, copy) NSString *displayName;
/// 是否群聊
@property (nonatomic, assign) BOOL isGroup;
/// 是否服务号（公众号）
@property (nonatomic, assign) BOOL isBrandService;
/// 是否企业号 / 企业微信（@openim、@ai.openim 等）
@property (nonatomic, assign) BOOL isEnterprise;
/// 是否置顶
@property (nonatomic, assign) BOOL isTop;
/// 是否被隐藏（微信自带的"不显示该聊天"）
@property (nonatomic, assign) BOOL isHidden;
/// 是否在聊天盒子内
@property (nonatomic, assign) BOOL isInChatBox;
/// 是否在服务号盒子内
@property (nonatomic, assign) BOOL isInBrandServiceBox;
/// 未读数（用于分组角标）
@property (nonatomic, assign) NSInteger unreadCount;
/// 是否免打扰（角标可据此显示小红点）
@property (nonatomic, assign) BOOL isMuted;
/// 所属微信标签名
@property (nonatomic, copy, nullable) NSArray<NSString *> *labelNames;
/// 原始会话对象（宿主自用，引擎不碰）
@property (nonatomic, strong, nullable) id rawObject;

+ (instancetype)sessionWithWxid:(NSString *)wxid name:(NSString *)name;

@end

/// 一个分组的计算结果（对应 WCPulseSessionInfo）
@interface WPGroupSessionInfo : NSObject

@property (nonatomic, copy) NSString *groupName;
@property (nonatomic, strong) NSMutableArray<WPGroupSession *> *normalSessions;
@property (nonatomic, strong) NSMutableArray<WPGroupSession *> *topSessions;
@property (nonatomic, assign) BOOL isAllSessions;
/// 分组角标数 = 所有会话未读之和
@property (nonatomic, readonly) NSInteger totalUnread;

- (instancetype)initWithGroupName:(NSString *)name;

@end

@class WPGroupEngine;
@protocol WPGroupSessionProvider <NSObject>
/// 返回当前全部会话（宿主从微信会话服务里取）
- (NSArray<WPGroupSession *> *)allSessionsForGroupEngine:(WPGroupEngine *)engine;
@end

@interface WPGroupEngine : NSObject

+ (instancetype)shared;

@property (nonatomic, weak, nullable) id<WPGroupSessionProvider> provider;

/// 分组名 -> WPGroupSessionInfo
@property (nonatomic, strong) NSMutableDictionary<NSString *, WPGroupSessionInfo *> *groups;
/// 当前选中分组
@property (nonatomic, strong, nullable) WPGroupSessionInfo *currentSelectGroup;
/// 上次刷新时间
@property (nonatomic, assign) NSTimeInterval lastReloadTime;

/// 分组顺序（取 config.groupFilterList，剔掉"服务号"入口被移除的情况）
- (NSArray<NSString *> *)groupList;

/// 初始化默认分组结构
- (void)setupDefaultGroups;
/// 配置里的分组列表变了就重建结构
- (void)syncGroupsFromConfigIfNeeded;
/// 重新计算所有分组（数据变了 / 开关变了都调它）
- (void)reloadSessions;
/// 切到某个分组（会持久化 defaultGroupIndex）
- (BOOL)selectGroupAtIndex:(NSInteger)index;

/// 核心过滤：按分组名取会话，needTop=YES 取置顶段，否则普通段
- (NSArray<WPGroupSession *> *)filterSessions:(NSArray<WPGroupSession *> *)allSessions
                                withGroupName:(NSString *)groupName
                                      needTop:(BOOL)needTop;

/// 该会话是否已经归到别的分组（用于置顶去重）
- (BOOL)isSessionInOtherGroups:(WPGroupSession *)session
                   allSessions:(NSArray<WPGroupSession *> *)allSessions;

/// 当前分组名（没选中时返回"全部"）
- (NSString *)currentGroupName;

@end

NS_ASSUME_NONNULL_END
