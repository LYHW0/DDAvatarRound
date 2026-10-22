//
//  WPGroupConfig.h
//  会话分组功能 —— 配置层
//
//  逆向自 WCPulse 分组模块（WCPulseConfig 分组相关字段）
//  存储：独立 plist，key 与插件原名保持一致，便于与已有配置互相迁移
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 分组相关设置变更通知（与逆向原实现同名，宿主直接监听即可）
extern NSString * const WPGroupFilterSettingChanged;              // 启用会话分组
extern NSString * const WPGroupIndicatorSettingChanged;           // 指示器样式/颜色
extern NSString * const WPGroupBadgeSettingChanged;               // 隐藏分组角标
extern NSString * const WPGroupBackgroundColorSettingChanged;     // 背景颜色 / 隐藏背景
extern NSString * const WPGroupFontColorSettingChanged;           // 选中/未选中字体颜色
extern NSString * const WPGroupFontSizeSettingChanged;            // 字体大小
extern NSString * const WPGroupListChanged;                       // 分组列表被增删改
extern NSString * const WPGroupAllBadgeSettingChanged;            // 隐藏"全部"角标
extern NSString * const WPGroupServiceAccountBadgeSettingChanged; // 隐藏"服务号"角标
extern NSString * const WPGroupTopFilterSettingChanged;           // 启用置顶过滤
extern NSString * const WPGroupGlobalGestureSettingChanged;       // 全屏手势
extern NSString * const WPGroupBottomBarGestureSettingChanged;    // 底栏手势
extern NSString * const WPGroupTransitionAnimationSettingChanged; // 过渡动画
extern NSString * const WPGroupFilterDuplicateContactsSettingChanged; // 过滤重复联系人
extern NSString * const WPGroupFoldTopSessionSettingChanged;      // 折叠置顶会话
extern NSString * const WPGroupSessionsReloaded;                  // 分组数据已重算（会话列表刷新用）

/// 分组设置（单例）
@interface WPGroupConfig : NSObject

+ (instancetype)shared;

/// 配置文件路径（Library/Preferences/WPGroup.plist）
@property (nonatomic, readonly) NSString *configFilePath;
/// 原始配置字典（可直接读写）
@property (nonatomic, readonly) NSMutableDictionary *configDictionary;
- (void)saveConfigDictionary:(NSDictionary *)dict;

#pragma mark - 分组列表

/// 启用的分组顺序（"全部/群聊/好友/服务号/企业号" + 标签名 + 自定义分组名）
@property (nonatomic, copy) NSArray<NSString *> *groupFilterList;
/// 自定义分组：分组名 -> 成员 wxid 数组
@property (nonatomic, copy) NSDictionary<NSString *, NSArray<NSString *> *> *customGroupList;
/// 分组显示名映射（原名 -> 自定义显示名）
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *groupNameMapping;
/// 默认选中的分组下标
@property (nonatomic, assign) NSInteger defaultGroupIndex;
/// 取分组显示名（有映射用映射，否则原名）
- (NSString *)mappedGroupName:(NSString *)name;

#pragma mark - 总开关与列表行为

/// 启用会话分组（关掉后会话列表回到原生，不带分组条）
@property (nonatomic, assign) BOOL enableGroupFilter;
/// 隐藏分组指示器（分组条下面的线条/圆点）
@property (nonatomic, assign) BOOL hideGroupIndicator;
/// 隐藏分组角标（每个分组上的未读数）
@property (nonatomic, assign) BOOL hideGroupBadge;
/// 启用置顶过滤（各分组内独立保留置顶会话的排序）
@property (nonatomic, assign) BOOL enableTopFilter;
/// 启用全屏手势切换分组
@property (nonatomic, assign) BOOL enableGlobalSwitchGroupGesture;
/// 启用底栏手势切换分组
@property (nonatomic, assign) BOOL enableBottomBarSwitchGroupGesture;
/// 分组切换过渡动画（设置页"移除过渡动画"取反写入）
@property (nonatomic, assign) BOOL enableGroupTransitionAnimation;
/// 隐藏"全部"分组角标
@property (nonatomic, assign) BOOL hideAllGroupBadge;
/// 隐藏"服务号"分组角标
@property (nonatomic, assign) BOOL hideServiceAccountBadge;
/// 隐藏分组背景颜色（跟会话列表同色）
@property (nonatomic, assign) BOOL hideGroupBackgroundColor;
/// 过滤重复联系人（同一联系人多个会话只留一个）
@property (nonatomic, assign) BOOL enableFilterDuplicateContacts;
/// 禁用折叠视图（置顶会话折叠成一行）
@property (nonatomic, assign) BOOL disableFoldTopSession;
/// 移除"服务号"入口
@property (nonatomic, assign) BOOL removeServiceAccount;

#pragma mark - 外观

/// 分组条背景色（十六进制字符串，如 #FFFFFF）
@property (nonatomic, copy) NSString *groupBackgroundColor;
@property (nonatomic, copy) NSString *groupBackgroundColorDark;
/// 指示器颜色
@property (nonatomic, copy) NSString *groupIndicatorColor;
@property (nonatomic, copy) NSString *groupIndicatorColorDark;
/// 选中文字颜色
@property (nonatomic, copy) NSString *groupFontColor;
@property (nonatomic, copy) NSString *groupFontColorDark;
/// 未选中文字颜色
@property (nonatomic, copy) NSString *groupUnselectedFontColor;
@property (nonatomic, copy) NSString *groupUnselectedFontColorDark;
/// 字体大小（10 ~ 20）
@property (nonatomic, assign) CGFloat groupFontSize;
/// 指示器样式：0 = 线条，1 = 圆圈
@property (nonatomic, assign) NSInteger groupIndicatorStyle;

#pragma mark - 工具

/// 深色模式下当前应使用的颜色字符串
- (NSString *)colorStringForKey:(NSString *)baseKey darkKey:(NSString *)darkKey;
+ (UIColor *)colorFromHexString:(NSString *)hex;
+ (NSString *)hexStringFromColor:(UIColor *)color;

/// 恢复默认外观（设置页"重置默认设置"）
- (void)resetAppearanceDefaults;

@end

NS_ASSUME_NONNULL_END
