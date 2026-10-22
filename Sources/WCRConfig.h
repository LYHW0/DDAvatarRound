//
//  WCRConfig.h
//  WCRefineRebuild
//
//  基于 WCRefine 2.1-9 逆向分析完整还原的配置头文件
//  包含 ~150+ 圆角相关配置键，保持与原版同名以支持配置迁移
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const WCRSettingsChangedNotification;

@interface WCRConfig : NSObject

+ (instancetype)shared;
- (void)reload;
- (id _Nullable)objectForKey:(NSString *)key def:(id _Nullable)def;
- (void)setObject:(id _Nullable)value forKey:(NSString *)key;

#pragma mark - 全局圆角配置（Global Corner）

@property (nonatomic, assign) BOOL globalCornerEnabled;
@property (nonatomic, assign) double globalCornerRadius;
@property (nonatomic, assign) double globalCornerMargin;
@property (nonatomic, assign) double globalCornerSpacing;
@property (nonatomic, assign) double globalCornerStroke;
@property (nonatomic, copy) NSString *globalCornerStrokeStyle;
@property (nonatomic, copy) NSString *globalCornerStrokeColorLight;
@property (nonatomic, copy) NSString *globalCornerStrokeColorDark;
@property (nonatomic, copy) NSString *globalCornerBackgroundColorLight;
@property (nonatomic, copy) NSString *globalCornerBackgroundColorDark;
@property (nonatomic, assign) BOOL globalCornerPinButtonV2;
@property (nonatomic, copy) NSArray<NSString *> *globalCornerCustomExcludedVCClassNames;

#pragma mark - 页面级圆角开关

@property (nonatomic, assign) BOOL homepageCornerEnabled;
@property (nonatomic, assign) BOOL mainFrameCornerEnabled;
@property (nonatomic, assign) BOOL settingPageCornerEnabled;
@property (nonatomic, assign) BOOL discoverPageCornerEnabled;
@property (nonatomic, assign) BOOL myPageCornerEnabled;
@property (nonatomic, assign) BOOL friendProfileCornerEnabled;
@property (nonatomic, assign) BOOL tpModeCornerEnabled;

@property (nonatomic, assign) BOOL appearanceUsesGlobalCorners;
@property (nonatomic, assign) BOOL profileFollowGlobalCornerEnabled;
@property (nonatomic, assign) BOOL profileCornerRadiusEnabled;

#pragma mark - 主列表专用间距参数

@property (nonatomic, assign) BOOL mainFrameSpacingUnifyEnabled;
@property (nonatomic, assign) BOOL belowPinnedUsesGlobalCard;
@property (nonatomic, assign) double belowPinnedSectionHeight;
@property (nonatomic, assign) double belowPinnedContentGap;
@property (nonatomic, assign) double pinnedTopSpacing;
@property (nonatomic, assign) double belowPinnedSpacing;

#pragma mark - 头像圆角（Avatar Corner）

@property (nonatomic, assign) BOOL avatarCornerEnabled;
@property (nonatomic, assign) double avatarCornerRadius;
@property (nonatomic, assign) double avatarCornerScale;
@property (nonatomic, assign) BOOL avatarCornerScaleEnabled;
@property (nonatomic, copy) NSString *avatarCornerScaleSceneFilter;
@property (nonatomic, assign) BOOL avatarCornerBorderEnabled;
@property (nonatomic, assign) double avatarCornerBorderSize;
@property (nonatomic, copy) NSString *avatarCornerBorderColorLight;
@property (nonatomic, copy) NSString *avatarCornerBorderColorDark;

@property (nonatomic, assign) BOOL avatarCornerChatPageEnabled;
@property (nonatomic, assign) double avatarCornerChatPageRadius;
@property (nonatomic, assign) BOOL avatarCornerChatPageBorderEnabled;
@property (nonatomic, assign) double avatarCornerChatPageBorderSize;
@property (nonatomic, copy) NSString *avatarCornerChatPageBorderColorLight;
@property (nonatomic, copy) NSString *avatarCornerChatPageBorderColorDark;

@property (nonatomic, assign) double avatarCornerProfileScale;

#pragma mark - 聊天气泡圆角

@property (nonatomic, assign) BOOL chatBubbleCornerEnabled;
@property (nonatomic, assign) double chatBubbleCornerRadius;
@property (nonatomic, assign) double chatBubbleCornerBorderSize;
@property (nonatomic, copy) NSString *chatBubbleCornerBorderColorLight;
@property (nonatomic, copy) NSString *chatBubbleCornerBorderColorDark;
@property (nonatomic, assign) BOOL chatBubbleArrowHidden;

#pragma mark - 聊天图片圆角

@property (nonatomic, assign) BOOL chatImageCornerEnabled;
@property (nonatomic, assign) double chatImageCornerRadius;
@property (nonatomic, assign) double chatImageCornerBorderSize;
@property (nonatomic, copy) NSString *chatImageCornerBorderColorLight;
@property (nonatomic, copy) NSString *chatImageCornerBorderColorDark;

#pragma mark - 聊天时间戳圆角

@property (nonatomic, assign) BOOL chatTimeRoundCornerEnabled;
@property (nonatomic, assign) double chatTimeRoundCornerRadius;
@property (nonatomic, assign) double chatTimeRoundCornerBorderSize;
@property (nonatomic, copy) NSString *chatTimeRoundCornerBorderColorLight;
@property (nonatomic, copy) NSString *chatTimeRoundCornerBorderColorDark;

#pragma mark - 搜索框圆角

@property (nonatomic, assign) BOOL searchCornerEnabled;
@property (nonatomic, assign) double searchCornerRadius;
@property (nonatomic, assign) double searchCornerMargin;
@property (nonatomic, assign) double searchCornerBorderSize;
@property (nonatomic, copy) NSString *searchCornerBorderColorLight;
@property (nonatomic, copy) NSString *searchCornerBorderColorDark;

#pragma mark - 输入框圆角

@property (nonatomic, assign) BOOL inputCornerEnabled;
@property (nonatomic, assign) double inputCornerRadius;
@property (nonatomic, assign) double inputCornerBorderSize;
@property (nonatomic, copy) NSString *inputCornerBorderColorLight;
@property (nonatomic, copy) NSString *inputCornerBorderColorDark;
@property (nonatomic, assign) BOOL inputCornerBoxTransparencyEnabled;
@property (nonatomic, assign) double inputCornerBoxTransparencyAlpha;

#pragma mark - 菜单圆角

@property (nonatomic, assign) BOOL menuCornerEnabled;
@property (nonatomic, assign) double menuCornerRadius;
@property (nonatomic, assign) double menuCornerBorderSize;
@property (nonatomic, copy) NSString *menuCornerBorderColorLight;
@property (nonatomic, copy) NSString *menuCornerBorderColorDark;

@property (nonatomic, assign) BOOL plusMenuCornerEnabled;
@property (nonatomic, assign) double plusMenuCornerRadius;

@property (nonatomic, assign) BOOL mainFrameSwipeMenuCornerEnabled;
@property (nonatomic, assign) double mainFrameSwipeMenuCornerRadius;

#pragma mark - 导航栏 / TabBar 圆角

@property (nonatomic, assign) BOOL topbarCornerEnabled;
@property (nonatomic, assign) double topbarCornerRadius;
@property (nonatomic, assign) BOOL topbarCornerTopFlatEnabled;
@property (nonatomic, assign) double topbarCornerBorderSize;
@property (nonatomic, copy) NSString *topbarCornerBorderColorLight;
@property (nonatomic, copy) NSString *topbarCornerBorderColorDark;

@property (nonatomic, assign) BOOL toolbarCornerEnabled;
@property (nonatomic, assign) double toolbarCornerRadius;
@property (nonatomic, assign) BOOL toolbarCornerBottomFlatEnabled;
@property (nonatomic, assign) double toolbarCornerBorderSize;
@property (nonatomic, copy) NSString *toolbarCornerBorderColorLight;
@property (nonatomic, copy) NSString *toolbarCornerBorderColorDark;

#pragma mark - 系统弹窗/提示圆角

@property (nonatomic, assign) BOOL systemPopupCornerEnabled;
@property (nonatomic, assign) double systemPopupCornerRadius;
@property (nonatomic, assign) double systemPopupCornerBorderSize;
@property (nonatomic, copy) NSString *systemPopupCornerBorderColorLight;
@property (nonatomic, copy) NSString *systemPopupCornerBorderColorDark;

@property (nonatomic, assign) BOOL systemNoticeCornerEnabled;
@property (nonatomic, assign) double systemNoticeCornerRadius;
@property (nonatomic, assign) double systemNoticeCornerBorderSize;
@property (nonatomic, copy) NSString *systemNoticeCornerBorderColorLight;
@property (nonatomic, copy) NSString *systemNoticeCornerBorderColorDark;

@property (nonatomic, assign) BOOL systemMessageCornerEnabled;
@property (nonatomic, assign) double systemMessageCornerRadius;
@property (nonatomic, assign) double systemMessageCornerBorderSize;
@property (nonatomic, copy) NSString *systemMessageCornerBorderColorLight;
@property (nonatomic, copy) NSString *systemMessageCornerBorderColorDark;

#pragma mark - Emoji / 表情圆角

@property (nonatomic, assign) BOOL emojiCornerEnabled;
@property (nonatomic, assign) double emojiCornerRadius;
@property (nonatomic, assign) double emojiCornerBorderSize;
@property (nonatomic, copy) NSString *emojiCornerBorderColorLight;
@property (nonatomic, copy) NSString *emojiCornerBorderColorDark;

#pragma mark - 资料卡 / 个人资料圆角

@property (nonatomic, assign) BOOL profileCornerEnabled;
@property (nonatomic, assign) double profileCornerRadius;
@property (nonatomic, assign) double profileCornerMargin;
@property (nonatomic, assign) double profileAvatarCornerRadius;
@property (nonatomic, assign) BOOL profileAvatarCornerOverrideEnabled;
@property (nonatomic, assign) double chatAvatarProfileCardAvatarCornerRadius;

#pragma mark - 其他组件圆角

@property (nonatomic, assign) BOOL finderCornerEnabled;
@property (nonatomic, assign) double finderCornerRadius;
@property (nonatomic, assign) double finderCornerBorderSize;
@property (nonatomic, copy) NSString *finderCornerBorderColorLight;
@property (nonatomic, copy) NSString *finderCornerBorderColorDark;

@property (nonatomic, assign) BOOL serviceCornerEnabled;
@property (nonatomic, assign) double serviceCornerRadius;
@property (nonatomic, assign) double serviceCornerBorderSize;
@property (nonatomic, copy) NSString *serviceCornerBorderColorLight;
@property (nonatomic, copy) NSString *serviceCornerBorderColorDark;

@property (nonatomic, assign) BOOL momentCornerEnabled;
@property (nonatomic, assign) double momentCornerRadius;
@property (nonatomic, assign) double momentCornerBorderSize;
@property (nonatomic, copy) NSString *momentCornerBorderColorLight;
@property (nonatomic, copy) NSString *momentCornerBorderColorDark;
@property (nonatomic, assign) BOOL momentCornerUnifiedEnabled;
@property (nonatomic, assign) BOOL momentOperateMenuCornerEnabled;

@property (nonatomic, assign) BOOL msgReferCornerEnabled;
@property (nonatomic, assign) double msgReferCornerRadius;
@property (nonatomic, assign) double msgReferCornerBorderSize;
@property (nonatomic, copy) NSString *msgReferCornerBorderColorLight;
@property (nonatomic, copy) NSString *msgReferCornerBorderColorDark;

@property (nonatomic, assign) BOOL imeKeyboardCornerEnabled;
@property (nonatomic, assign) double imeKeyboardCornerRadius;
@property (nonatomic, assign) double imeKeyboardCornerBorderSize;
@property (nonatomic, copy) NSString *imeKeyboardCornerBorderColorLight;
@property (nonatomic, copy) NSString *imeKeyboardCornerBorderColorDark;

@property (nonatomic, assign) BOOL quickReplyMsgCornerEnabled;
@property (nonatomic, assign) double quickReplyMsgCornerRadius;
@property (nonatomic, assign) double quickReplyMsgCornerBorderSize;
@property (nonatomic, copy) NSString *quickReplyMsgCornerBorderColorLight;
@property (nonatomic, copy) NSString *quickReplyMsgCornerBorderColorDark;

@property (nonatomic, assign) BOOL sendPublishButtonCornerEnabled;
@property (nonatomic, assign) double sendPublishButtonCornerRadius;
@property (nonatomic, assign) double sendPublishButtonCornerBorderSize;
@property (nonatomic, copy) NSString *sendPublishButtonCornerBorderColorLight;
@property (nonatomic, copy) NSString *sendPublishButtonCornerBorderColorDark;

@property (nonatomic, assign) BOOL voiceTranslateCornerEnabled;
@property (nonatomic, assign) double voiceTranslateCornerRadius;
@property (nonatomic, assign) double voiceTranslateCornerBorderSize;
@property (nonatomic, copy) NSString *voiceTranslateCornerBorderColorLight;
@property (nonatomic, copy) NSString *voiceTranslateCornerBorderColorDark;

@property (nonatomic, assign) BOOL chatLocationCornerEnabled;
@property (nonatomic, assign) BOOL chatFileCornerEnabled;

// ---- legacy (menu/banner/profile card) ----
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

@property (nonatomic, assign) BOOL floatingTabBarEnabled;
@property (nonatomic, assign) BOOL cardShadowEnabled;
@property (nonatomic, assign) double myPageCornerRadius;
@property (nonatomic, assign) double myPageCornerMargin;
@property (nonatomic, assign) double cardShadowStrength;
@property (nonatomic, assign) BOOL timelineCornerEnabled;
@property (nonatomic, assign) double timelineCornerRadius;
@property (nonatomic, assign) BOOL timelineMediaCornerEnabled;
@property (nonatomic, assign) double timelineMediaCornerRadius;
@property (nonatomic, assign) BOOL timelineCommentCornerEnabled;
@property (nonatomic, assign) double timelineCommentCornerRadius;
@property (nonatomic, assign) BOOL forwardPickerCornerEnabled;
@property (nonatomic, assign) double forwardPickerCornerRadius;
@property (nonatomic, assign) BOOL profilePageCornerEnabled;
@property (nonatomic, assign) BOOL groupInfoCornerEnabled;
@property (nonatomic, assign) BOOL servicePageCornerEnabled;
@property (nonatomic, assign) double servicePageCornerRadius;

@end

NS_ASSUME_NONNULL_END
