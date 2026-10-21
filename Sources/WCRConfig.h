//
//  WCRConfig.h
//  WCRefineRebuild
//
//  配置中心。key 命名与原版 WCRefine 完全一致（从二进制里还原出来的属性名），
//  所以老用户的配置可以直接沿用；值统一存在 NSUserDefaults 套件里。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 设置变更通知（与原版同名的语义：改完立刻生效，不用重启微信）
extern NSString * const WCRSettingsChangedNotification;

@interface WCRConfig : NSObject

+ (instancetype)shared;

/// 重新从磁盘加载（收到设置变更通知时调用）
- (void)reload;

// ---------------- 全局（界面圆角板块） ----------------
@property (nonatomic, assign) BOOL homepageCornerEnabled;      // 主界面（会话列表）
@property (nonatomic, assign) BOOL mainFrameCornerEnabled;     // 主框架
@property (nonatomic, assign) BOOL mainFrameSpacingUnifyEnabled; // 列表卡片化间距
@property (nonatomic, assign) BOOL discoverPageCornerEnabled;   // 发现页
@property (nonatomic, assign) BOOL myPageCornerEnabled;         // 我的页
@property (nonatomic, assign) double globalCornerRadius;        // 默认 15
@property (nonatomic, assign) double globalCornerSpacing;       // 卡片间距
@property (nonatomic, assign) double globalCornerMargin;        // 左右留白
@property (nonatomic, assign) double globalCornerStroke;        // 描边宽度
@property (nonatomic, copy)   NSString *globalCornerBackgroundColorLight;
@property (nonatomic, copy)   NSString *globalCornerBackgroundColorDark;
@property (nonatomic, copy)   NSString *globalCornerStrokeColorLight;
@property (nonatomic, copy)   NSString *globalCornerStrokeColorDark;

// ---------------- 头像框圆角板块 ----------------
@property (nonatomic, assign) BOOL avatarCornerEnabled;
@property (nonatomic, assign) double avatarCornerRadius;       // 百分比（100 = 正圆）
@property (nonatomic, assign) BOOL avatarCornerScaleEnabled;   // 头像缩放
@property (nonatomic, assign) double avatarCornerScale;        // 0.6 ~ 1.0
@property (nonatomic, assign) BOOL avatarCornerBorderEnabled;
@property (nonatomic, assign) double avatarCornerBorderSize;
@property (nonatomic, copy)   NSString *avatarCornerBorderColorLight;
@property (nonatomic, copy)   NSString *avatarCornerBorderColorDark;
@property (nonatomic, assign) BOOL avatarCornerChatPageEnabled;
@property (nonatomic, assign) double avatarCornerChatPageRadius;
@property (nonatomic, assign) BOOL avatarCornerChatPageBorderEnabled;
@property (nonatomic, assign) double avatarCornerChatPageBorderSize;
@property (nonatomic, copy)   NSString *avatarCornerChatPageBorderColorLight;
@property (nonatomic, copy)   NSString *avatarCornerChatPageBorderColorDark;

// ---------------- 资料卡美化板块 ----------------
@property (nonatomic, assign) BOOL profileCornerEnabled;
@property (nonatomic, assign) BOOL profileFollowGlobalCornerEnabled;
@property (nonatomic, assign) double profileCornerRadius;
@property (nonatomic, assign) double profileCornerMargin;
@property (nonatomic, assign) BOOL profileCardBeautifyEnabled;
@property (nonatomic, assign) double profileCardCardAlpha;
@property (nonatomic, assign) double profileCardBackgroundImageAlpha;
@property (nonatomic, copy)   NSString *profileCardBackgroundImagePath;
@property (nonatomic, copy)   NSString *profileCardBackgroundLightColor;
@property (nonatomic, copy)   NSString *profileCardBackgroundDarkColor;
@property (nonatomic, copy)   NSString *profileCardNameLightColor;
@property (nonatomic, copy)   NSString *profileCardNameDarkColor;
@property (nonatomic, copy)   NSString *profileCardSignatureLightColor;
@property (nonatomic, copy)   NSString *profileCardSignatureDarkColor;
@property (nonatomic, assign) BOOL profileCardWechatIDHiddenByDefault;

// ---------------- 消息横幅美化板块 ----------------
@property (nonatomic, assign) BOOL msgBannerBeautifyEnabled;
@property (nonatomic, assign) double msgBannerHeight;
@property (nonatomic, assign) double msgBannerWidth;
@property (nonatomic, assign) double msgBannerExtraMargin;
@property (nonatomic, assign) double msgBannerStaySeconds;
@property (nonatomic, assign) double msgBannerMaxTextLength;
@property (nonatomic, copy)   NSString *msgBannerMaxTextOverflowSuffix;
@property (nonatomic, assign) BOOL msgBannerBgUseImageBackground;
@property (nonatomic, copy)   NSString *msgBannerBgImageFolder;
@property (nonatomic, assign) double msgBannerBgImageAlpha;
@property (nonatomic, assign) double msgBannerBgImageOffsetX;
@property (nonatomic, assign) double msgBannerBgImageOffsetY;
@property (nonatomic, assign) BOOL msgBannerBgColorEnabled;
@property (nonatomic, copy)   NSString *msgBannerBgColorLight;
@property (nonatomic, copy)   NSString *msgBannerBgColorDark;
@property (nonatomic, assign) BOOL msgBannerFrostColorEnabled;
@property (nonatomic, copy)   NSString *msgBannerFrostColorLight;
@property (nonatomic, copy)   NSString *msgBannerFrostColorDark;
@property (nonatomic, assign) BOOL msgBannerNicknameColorEnabled;
@property (nonatomic, copy)   NSString *msgBannerNicknameColorLight;
@property (nonatomic, copy)   NSString *msgBannerNicknameColorDark;
@property (nonatomic, assign) BOOL msgBannerContentColorEnabled;
@property (nonatomic, copy)   NSString *msgBannerContentColorLight;
@property (nonatomic, copy)   NSString *msgBannerContentColorDark;

// ---------------- 菜单美化板块 ----------------
@property (nonatomic, assign) BOOL menuCornerEnabled;
@property (nonatomic, assign) double menuCornerRadius;
@property (nonatomic, assign) double menuCornerBorderSize;
@property (nonatomic, copy)   NSString *menuCornerBorderColorLight;
@property (nonatomic, copy)   NSString *menuCornerBorderColorDark;
@property (nonatomic, assign) BOOL plusMenuCornerEnabled;
@property (nonatomic, assign) double plusMenuCornerRadius;
@property (nonatomic, assign) double plusMenuBorderSize;
@property (nonatomic, copy)   NSString *plusMenuBorderColorLight;
@property (nonatomic, copy)   NSString *plusMenuBorderColorDark;
@property (nonatomic, assign) BOOL menuUseImageBackground;
@property (nonatomic, copy)   NSString *menuBackgroundImageFolder;
@property (nonatomic, assign) double menuBackgroundViewAlpha;
@property (nonatomic, assign) BOOL menuSizeEnabled;
@property (nonatomic, assign) double menuWidth;
@property (nonatomic, assign) double menuMaxCountPerLine;
@property (nonatomic, assign) BOOL menuColorEnabled;
@property (nonatomic, copy)   NSString *menuColorLight;
@property (nonatomic, copy)   NSString *menuColorDark;
@property (nonatomic, assign) BOOL menuTextColorEnabled;
@property (nonatomic, copy)   NSString *menuTextColorLight;
@property (nonatomic, copy)   NSString *menuTextColorDark;
@property (nonatomic, assign) BOOL menuIconColorEnabled;
@property (nonatomic, copy)   NSString *menuIconColorLight;
@property (nonatomic, copy)   NSString *menuIconColorDark;
@property (nonatomic, assign) BOOL menuTextCenterEnabled;

// ---------------- 通用 ----------------
- (id _Nullable)objectForKey:(NSString *)key def:(id _Nullable)def;
- (void)setObject:(id _Nullable)value forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
