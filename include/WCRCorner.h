//
//  WCRCorner.h
//  WCRefine 界面圆角 板块 —— 完整逆向复刻
//
//  逆向来源: WCRefine 2.1-9 (com.zaka.<redacted>, arm64, rootless)
//    - WCRefineCornerViewController            204 个方法 / 33,544 字节 reloadTableData
//    - WCRefineGlobalCornerSettingsViewController 49 个方法
//    - WCRefineConfig                         4861 个方法(其中 corner 相关 330 个)
//
//  本文件把原来分散的 14 个头文件合并为一个,业务逻辑全部 C++/Objective-C++。
//

#ifndef WCR_CORNER_H
#define WCR_CORNER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - ============================ 配置表 ============================
//
// 原插件 WCRefineConfig 的存取规则(逆向确认):
//   1. 全部设置存在一个 NSDictionary 里(键 = 存取器 selector 名,例如 @"searchCornerRadius")
//   2. getter 读不到时写回默认值并落盘
//   3. setter 负责 clamp,再落盘
//   4. 落盘调用 -saveConfigDictionary:
//
// 下面用 X-Macro 单表驱动:改一行,属性/默认值/范围/存取器四处同步。
//

//  BOOL 开关: X(键, 默认值)
#define WCR_BOOL_ITEMS(X)                                    \
    /* 页面级总开关 */                                        \
    X(homepageCornerEnabled,            NO )                 \
    X(mainFrameCornerEnabled,           YES)                 \
    X(mainFrameSwipeMenuCornerEnabled,  YES)                 \
    X(mainFrameSpacingUnifyEnabled,     NO )                 \
    X(myPageCornerEnabled,              NO )                 \
    X(friendProfileCornerEnabled,       NO )                 \
    X(discoverPageCornerEnabled,        NO )                 \
    X(tpModeCornerEnabled,              NO )                 \
    X(profileCornerEnabled,             NO )                 \
    X(profileCornerRadiusEnabled,       YES)                 \
    X(profileFollowGlobalCornerEnabled, NO )                 \
    X(profileAvatarCornerOverrideEnabled, NO)                \
    /* 搜索框 */                                              \
    X(searchCornerEnabled,              NO )                 \
    X(searchClearMaskEnabled,           NO )                 \
    X(searchTextPlaceholderEnabled,     NO )                 \
    /* 输入框 */                                              \
    X(inputCornerEnabled,               NO )                 \
    X(inputBoxTransparencyEnabled,      NO )                 \
    /* 输入法键盘 */                                          \
    X(imeKeyboardCornerEnabled,         NO )                 \
    /* 顶栏 / 底栏 */                                         \
    X(topbarCornerEnabled,              NO )                 \
    X(topbarCornerTopFlatEnabled,       NO )                 \
    X(groupTipsTransparencyEnabled,     NO )                 \
    X(toolbarCornerEnabled,             NO )                 \
    X(toolbarCornerBottomFlatEnabled,   NO )                 \
    /* 聊天内容 */                                            \
    X(emojiCornerEnabled,               NO )                 \
    X(chatImageCornerEnabled,           NO )                 \
    X(chatFileCornerEnabled,            NO )                 \
    X(chatLocationCornerEnabled,        NO )                 \
    X(chatBubbleCornerEnabled,          NO )                 \
    X(chatBubbleArrowHidden,            NO )                 \
    X(chatTimeRoundCornerEnabled,       NO )                 \
    X(chatTimeRoundBackgroundEnabled,   NO )                 \
    X(chatTimeRoundTextColorEnabled,    NO )                 \
    X(msgReferCornerEnabled,            NO )                 \
    X(msgReferColorEnabled,             NO )                 \
    X(systemMessageCornerEnabled,       NO )                 \
    X(systemMessageColorEnabled,        NO )                 \
    X(systemNoticeCornerEnabled,        NO )                 \
    X(systemNoticeColorEnabled,         NO )                 \
    X(voiceTranslateCornerEnabled,      NO )                 \
    X(voiceTranslateColorEnabled,       NO )                 \
    /* 朋友圈 / 视频号 / 服务号 */                            \
    X(momentCornerEnabled,              NO )                 \
    X(momentCornerUnifiedEnabled,       NO )                 \
    X(momentOperateMenuCornerEnabled,   NO )                 \
    X(finderCornerEnabled,              NO )                 \
    X(serviceCornerEnabled,             NO )                 \
    /* 加号菜单 */                                            \
    X(plusMenuCornerEnabled,            NO )                 \
    X(plusMenuBgColorEnabled,           NO )                 \
    X(plusMenuTextColorEnabled,         NO )                 \
    X(plusMenuIconColorEnabled,         NO )                 \
    /* 按钮 / 弹窗 */                                         \
    X(sendPublishButtonCornerEnabled,   NO )                 \
    X(systemPopupCornerEnabled,         NO )

//  整型数值: X(键, 默认值, 下限, 上限)
#define WCR_INT_ITEMS(X)                                     \
    X(globalCornerRadius,               15,  0,  50 )        \
    X(globalCornerMargin,               15,  0, 100 )        \
    X(globalCornerSpacing,              10,  0,  50 )        \
    X(globalCornerStroke,                0,  0,  50 )        \
    X(globalCornerStrokeStyle,           0,  0,   2 )        \
    X(mainFramePinnedTopSpacing,         0,  0, 100 )        \
    X(mainFrameBelowPinnedSpacing,       0,  0, 100 )        \
    X(mainFrameSwipeMenuCornerRadius,   20,  0,  50 )        \
    X(profileCornerRadius,              20,  0,  50 )        \
    X(profileCornerMargin,               8,  0,  50 )        \
    X(profileStrokeLineStyle,            0,  0,   2 )        \
    X(avatarCornerRadius,              100,  0, 100 )        \
    X(profileAvatarCornerRadius,       100,  0, 100 )        \
    X(chatAvatarProfileCardAvatarCornerRadius, 100, 0, 100 ) \
    X(searchCornerRadius,               15,  0,  30 )        \
    X(searchCornerMargin,                8,  0,  20 )        \
    X(inputCornerRadius,                15,  0,  30 )        \
    X(inputBoxTransparencyAlpha,        30,  0, 100 )        \
    X(imeKeyboardCornerRadius,          30,  0,  50 )        \
    X(topbarCornerRadius,               20,  0,  50 )        \
    X(groupTipsTransparencyAlpha,       30,  0, 100 )        \
    X(toolbarCornerRadius,              20,  0,  50 )        \
    X(emojiCornerRadius,                15,  0,  30 )        \
    X(chatImageCornerRadius,            15,  0,  30 )        \
    X(chatBubbleCornerRadius,           12,  0,  30 )        \
    X(chatTimeRoundCornerRadius,         8,  0,  30 )        \
    X(msgReferCornerRadius,             10,  0,  30 )        \
    X(systemMessageCornerRadius,        10,  0,  30 )        \
    X(systemNoticeCornerRadius,         10,  0,  30 )        \
    X(voiceTranslateCornerRadius,       10,  0,  30 )        \
    X(momentCornerRadius,               10,  0,  30 )        \
    X(finderCornerRadius,               10,  0,  30 )        \
    X(serviceCornerRadius,              10,  0,  30 )        \
    X(plusMenuCornerRadius,             15,  0,  30 )        \
    X(sendPublishButtonCornerRadius,    10,  0,  30 )        \
    X(systemPopupCornerRadius,          15,  0,  30 )        \
    X(quickReplyMsgCornerRadius,        25,  0,  50 )        \
    X(menuCornerRadius,                 25,  0,  50 )

//  浮点数值(描边宽度): X(键, 默认值, 下限, 上限)
#define WCR_FLOAT_ITEMS(X)                                   \
    X(searchCornerBorderSize,            0.f, 0.f, 5.f)      \
    X(inputCornerBorderSize,             0.f, 0.f, 5.f)      \
    X(imeKeyboardCornerBorderSize,       0.f, 0.f, 5.f)      \
    X(topbarCornerBorderSize,            0.f, 0.f, 5.f)      \
    X(toolbarCornerBorderSize,           0.f, 0.f, 5.f)      \
    X(emojiCornerBorderSize,             0.f, 0.f, 5.f)      \
    X(chatImageCornerBorderSize,         0.f, 0.f, 5.f)      \
    X(chatBubbleCornerBorderSize,        0.f, 0.f, 5.f)      \
    X(chatTimeRoundCornerBorderSize,     0.f, 0.f, 5.f)      \
    X(msgReferCornerBorderSize,          0.f, 0.f, 5.f)      \
    X(systemMessageCornerBorderSize,     0.f, 0.f, 5.f)      \
    X(systemNoticeCornerBorderSize,      0.f, 0.f, 5.f)      \
    X(voiceTranslateCornerBorderSize,    0.f, 0.f, 5.f)      \
    X(quickReplyMsgCornerBorderSize,     0.f, 0.f, 5.f)      \
    X(menuCornerBorderSize,              0.f, 0.f, 5.f)      \
    X(momentCornerBorderSize,            0.f, 0.f, 5.f)      \
    X(finderCornerBorderSize,            0.f, 0.f, 5.f)      \
    X(serviceCornerBorderSize,           0.f, 0.f, 5.f)      \
    X(plusMenuBorderSize,                0.f, 0.f, 5.f)      \
    X(sendPublishButtonCornerBorderSize, 0.f, 0.f, 5.f)      \
    X(systemPopupCornerBorderSize,       0.f, 0.f, 5.f)      \
    X(avatarCornerBorderSize,            0.f, 0.f, 5.f)      \
    X(globalCornerPinButtonV2,           1.f, 0.f, 1.f)      \
    X(avatarCornerChatPageBorderSize,    0.f, 0.f, 5.f)

//  成对深浅色: X(基名, 浅色默认 hex, 深色默认 hex)
#define WCR_COLOR_ITEMS(X)                                          \
    X(searchCornerBorderColor,        0x000000, 0xFFFFFF)           \
    X(inputCornerBorderColor,         0x000000, 0xFFFFFF)           \
    X(imeKeyboardCornerBorderColor,   0x000000, 0xFFFFFF)           \
    X(topbarCornerBorderColor,        0x000000, 0xFFFFFF)           \
    X(toolbarCornerBorderColor,       0x000000, 0xFFFFFF)           \
    X(emojiCornerBorderColor,         0x000000, 0xFFFFFF)           \
    X(chatImageCornerBorderColor,     0x000000, 0xFFFFFF)           \
    X(chatBubbleCornerBorderColor,    0x000000, 0xFFFFFF)           \
    X(chatTimeRoundCornerBorderColor, 0x000000, 0xFFFFFF)           \
    X(msgReferCornerBorderColor,      0x000000, 0xFFFFFF)           \
    X(systemMessageCornerBorderColor, 0x000000, 0xFFFFFF)           \
    X(systemNoticeCornerBorderColor,  0x000000, 0xFFFFFF)           \
    X(voiceTranslateCornerBorderColor,0x000000, 0xFFFFFF)           \
    X(momentCornerBorderColor,        0x000000, 0xFFFFFF)           \
    X(finderCornerBorderColor,        0x000000, 0xFFFFFF)           \
    X(serviceCornerBorderColor,       0x000000, 0xFFFFFF)           \
    X(plusMenuBorderColor,            0x000000, 0xFFFFFF)           \
    X(sendPublishButtonBorderColor,   0x000000, 0xFFFFFF)           \
    X(systemPopupBorderColor,         0x000000, 0xFFFFFF)           \
    X(globalCornerBackgroundColor,    0xFFFFFF, 0x1C1C1E)           \
    X(globalCornerStrokeColor,        0x000000, 0xFFFFFF)           \
    X(chatTimeRoundBackgroundColor,   0x000000, 0xFFFFFF)           \
    X(chatTimeRoundTextColor,         0xFFFFFF, 0x000000)           \
    X(msgReferColor,                  0xF2F2F2, 0x2C2C2E)           \
    X(systemMessageColor,             0xF2F2F2, 0x2C2C2E)           \
    X(systemNoticeColor,              0xF2F2F2, 0x2C2C2E)           \
    X(voiceTranslateColorOther,       0xFFFFFF, 0x2C2C2E)           \
    X(voiceTranslateColorSelf,        0x95EC69, 0x3E9E4F)           \
    X(plusMenuBgColor,                0xFFFFFF, 0x1C1C1E)           \
    X(plusMenuTextColor,              0x000000, 0xFFFFFF)           \
    X(plusMenuIconColor,              0x000000, 0xFFFFFF)           \
    X(avatarCornerBorderColor,        0xFFFFFF, 0x000000)           \
    X(avatarCornerChatPageBorderColor,0xFFFFFF, 0x000000)

//  字符串: X(键, 默认值)
#define WCR_STRING_ITEMS(X)                                  \
    X(searchTextPlaceholder, @"平安喜樂 ✧٩(ˊωˋ*)و✧ ")        \
    X(globalCornerCustomExcludedVCClassNames, @"")

//  只读属性(沿用原插件命名,便于对照)
#define WCR_DERIVED_ITEMS(X)                                 \
    X(NSInteger, globalCornerCustomExcludedCount)

#pragma mark - ============================ 配置单例 ============================

@interface WCRCornerConfig : NSObject

+ (instancetype)shared;

#pragma mark 自动生成的存取器

// BOOL
#define WCR_DECL_BOOL(key, def) \
    - (BOOL)key;                \
    - (void)set##key:(BOOL)v;   \
    @property (nonatomic, assign) BOOL key;
WCR_BOOL_ITEMS(WCR_DECL_BOOL)
#undef WCR_DECL_BOOL

// 整型
#define WCR_DECL_INT(key, def, lo, hi) \
    - (NSInteger)key;                  \
    - (void)set##key:(NSInteger)v;     \
    @property (nonatomic, assign) NSInteger key;
WCR_INT_ITEMS(WCR_DECL_INT)
#undef WCR_DECL_INT

// 浮点
#define WCR_DECL_FLOAT(key, def, lo, hi) \
    - (CGFloat)key;                      \
    - (void)set##key:(CGFloat)v;         \
    @property (nonatomic, assign) CGFloat key;
WCR_FLOAT_ITEMS(WCR_DECL_FLOAT)
#undef WCR_DECL_FLOAT

// 颜色(成对)
#define WCR_DECL_COLOR(base, l, d)                                  \
    - (UIColor *)base##Light;                                       \
    - (void)set##base##Light:(UIColor *)c;                          \
    - (UIColor *)base##Dark;                                        \
    - (void)set##base##Dark:(UIColor *)c;
WCR_COLOR_ITEMS(WCR_DECL_COLOR)
#undef WCR_DECL_COLOR

// 字符串
#define WCR_DECL_STRING(key, def)      \
    - (NSString *)key;                 \
    - (void)set##key:(NSString *)v;    \
    @property (nonatomic, copy) NSString *key;
WCR_STRING_ITEMS(WCR_DECL_STRING)
#undef WCR_DECL_STRING

#pragma mark 通用工具

/// 当前外观下的颜色(深色模式自动取 Dark 版本)
#define WCR_COLOR(base) [WCRCornerConfig darkMode] ? \
    [WCRCornerConfig shared].base##Dark : [WCRCornerConfig shared].base##Light

/// 取当前外观下有效的描边宽度(0 表示不描边)
#define WCR_BORDER(key) ([WCRCornerConfig shared].key > 0.001 ? [WCRCornerConfig shared].key : 0.0)

+ (BOOL)darkMode;
+ (UIColor *)colorFromHex:(NSUInteger)hex;
+ (NSUInteger)hexValueFromColor:(UIColor *)color;
+ (NSString *)hexFromColor:(UIColor *)color;

/// 已排除页面的数量(原插件读 globalCornerCustomExcludedVCClassNames 逗号分隔计数)
- (NSInteger)globalCornerCustomExcludedCount;

/// 把所有圆角相关项恢复为出厂值(不含「主页全局圆角」,与原插件一致)
- (void)resetAllCornerSettings;

/// 通知(原插件 sendSettingsChangedNotification,60 字节,纯粹 postNotification)
- (void)notifyChanged;
/// 配置落盘
- (void)persist;

@end

extern NSString *const WCRCornerSettingsChangedNotification;

#pragma mark - ============================ 表格框架 ============================

typedef NS_ENUM(NSInteger, WCRRowKind) {
    WCRRowKindSwitch = 0,   ///< 右侧 UISwitch
    WCRRowKindValue,        ///< 右侧灰色数值 + 箭头
    WCRRowKindDisclosure,   ///< 右侧色点/控件 + 箭头
    WCRRowKindButton,       ///< 居中按钮
    WCRRowKindSegment,      ///< 右侧 UISegmentedControl
};

@class WCRTableSection, WCRTableRow;

typedef void (^WCRRowAction)(void);

@interface WCRTableRow : NSObject
@property (nonatomic, assign) WCRRowKind kind;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *iconName;
@property (nonatomic, copy, nullable) NSString *valueText;   ///< 右侧显示文本
@property (nonatomic, assign) BOOL on;                        ///< 开关状态
@property (nonatomic, assign) BOOL destructive;               ///< 红色文字
@property (nonatomic, strong, nullable) UIView *rightView;    ///< 自定义右视图(色点等)
@property (nonatomic, copy, nullable) WCRRowAction action;
@property (nonatomic, copy, nullable) void (^switchAction)(BOOL on);

+ (instancetype)rowWithKind:(WCRRowKind)kind title:(NSString *)title;
+ (instancetype)switchRow:(NSString *)title on:(BOOL)on action:(void (^)(BOOL))action;
+ (instancetype)valueRow:(NSString *)title value:(NSString *)value action:(void (^)(void))action;
+ (instancetype)accessoryRow:(NSString *)title rightView:(UIView *)view action:(void (^)(void))action;
+ (instancetype)buttonRow:(NSString *)title destructive:(BOOL)destructive action:(void (^)(void))action;
@end

@interface WCRTableSection : NSObject
@property (nonatomic, copy, nullable) NSString *header;
@property (nonatomic, copy, nullable) NSString *footer;
@property (nonatomic, strong) NSMutableArray<WCRTableRow *> *rows;
+ (instancetype)sectionWithHeader:(nullable NSString *)header footer:(nullable NSString *)footer;
- (void)addRow:(WCRTableRow *)row;
@end

/// 微信设置页同款表格容器(白底/分组卡片/浅灰背景/自动高度)
@interface WCRTableViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<WCRTableSection *> *sections;
- (void)addSection:(WCRTableSection *)section;
- (void)reloadTableData;
- (void)runHaptic;   ///< 轻触反馈(UIImpactFeedbackGenerator light)
@end

#pragma mark - ============================ 主板块 VC ============================

/// 对应 WCRefineCornerViewController (204 方法)
@interface WCRCornerViewController : WCRTableViewController
@end

/// 对应 WCRefineGlobalCornerSettingsViewController (49 方法)
@interface WCRGlobalCornerViewController : WCRTableViewController
@end

#pragma mark - ============================ 圆角引擎 ============================

typedef NS_ENUM(NSInteger, WCRCornerTarget) {
    WCRCornerTargetSearchBar,
    WCRCornerTargetInputBar,
    WCRCornerTargetKeyboard,
    WCRCornerTargetTopbar,
    WCRCornerTargetToolbar,
    WCRCornerTargetEmoji,
    WCRCornerTargetChatImage,
    WCRCornerTargetChatBubble,
    WCRCornerTargetChatTime,
    WCRCornerTargetMsgRefer,
    WCRCornerTargetSystemMessage,
    WCRCornerTargetSystemNotice,
    WCRCornerTargetVoiceTranslate,
    WCRCornerTargetMoment,
    WCRCornerTargetFinder,
    WCRCornerTargetService,
    WCRCornerTargetPlusMenu,
    WCRCornerTargetSendButton,
    WCRCornerTargetSystemPopup,
    WCRCornerTargetSwipeMenu,
};

/// 圆角渲染引擎:把配置套到具体 view 上(纯 C++ 实现,ObjC++ 只做桥接)
class WCRCornerPainter {
public:
    /// 按目标取圆角半径
    static double radiusForTarget(WCRCornerTarget t);
    /// 按目标取描边宽度
    static double borderWidthForTarget(WCRCornerTarget t);
    /// 按目标取描边颜色 rgba(0xRRGGBBAA)
    static unsigned int borderColorForTarget(WCRCornerTarget t);
    /// 把圆角/描边套到 view 上(rootless 安全,不改 layer.mask)
    static void apply(CALayer *layer, WCRCornerTarget t);
    /// 只切某个角(顶栏顶部不圆 / 底栏底部不圆)
    static void applyCorners(CALayer *layer, WCRCornerTarget t,
                             bool topLeft, bool topRight, bool bottomLeft, bool bottomRight);
};

/// 统一的"打补丁"入口:所有 hook 都走这里,保证同一 view 只处理一次
@interface WCRCornerHookCenter : NSObject
+ (void)applyToView:(UIView *)view target:(WCRCornerTarget)target;
+ (void)install;
@end

#pragma mark - ============================ 插件注册入口 ============================
//
// 只走 WCPluginsMgr(插件收纳的统一注册中心),按三级顺序降级:
//   1. WCPluginsMgr(运行时按名字取,单例/类方法都试)
//   2. WCRefinePluginHubManager -registerPluginForCustomEntry:(条目 "名称@控制器")
//   3. 设置页兜底入口(注册失败时才出现,保证一定能进面板)
//

extern NSString *const WCRPluginDidRegisterNotification;
extern NSString *const WCRPluginEntryTitle;
extern NSString *const WCRPluginEntryControllerName;

@interface WCRPluginRegistrar : NSObject
+ (void)registerAll;              ///< 注册到 WCPluginsMgr / 插件收纳
+ (BOOL)isRegistered;
+ (BOOL)needsFallbackEntry;       ///< 注册失败返回 YES
+ (UIViewController *)makeEntryViewController;
@end

NS_ASSUME_NONNULL_END

#endif /* WCR_CORNER_H */
