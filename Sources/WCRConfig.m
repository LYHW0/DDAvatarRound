//
//  WCRConfig.m
//  WCRefineRebuild
//
//  基于 WCRefine 2.1-9 逆向分析完整还原的配置实现
//  162 个圆角相关配置键，使用宏简化代码
//

#import "WCRConfig.h"
#import <notify.h>

NSString * const WCRSettingsChangedNotification = @"com.qimiao.wcrefine.settings_changed";

static NSString * const kWRCSuiteName = @"com.qimiao.WCRefine.rebuild";

@interface WCRConfig ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@end

@implementation WCRConfig

+ (instancetype)shared {
    static WCRConfig *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[WCRConfig alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:kWRCSuiteName];

        __weak typeof(self) weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:WCRSettingsChangedNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            [weakSelf reload];
        }];
    }
    return self;
}

- (void)reload {
    [self.defaults synchronize];
}

- (id _Nullable)objectForKey:(NSString *)key def:(id _Nullable)def {
    id v = [self.defaults objectForKey:key];
    if (v == nil || v == [NSNull null]) return def;
    return v;
}

- (void)setObject:(id _Nullable)value forKey:(NSString *)key {
    if (value == nil) {
        [self.defaults removeObjectForKey:key];
    } else {
        [self.defaults setObject:value forKey:key];
    }
}

#pragma mark - 取值便捷宏

#define WCR_BOOL(prop, key, defv) \
- (BOOL)prop { return [self objectForKey:@#key def:@(defv)] ? [[self objectForKey:@#key def:@(defv)] boolValue] : defv; } \
- (void)set##prop:(BOOL)v { [self setObject:@(v) forKey:@#key]; }

#define WCR_DOUBLE(prop, key, defv) \
- (double)prop { id o = [self objectForKey:@#key def:nil]; return o ? [o doubleValue] : defv; } \
- (void)set##prop:(double)v { [self setObject:@(v) forKey:@#key]; }

#define WCR_STRING(prop, key, defv) \
- (NSString *)prop { id o = [self objectForKey:@#key def:nil]; return o ?: defv; } \
- (void)set##prop:(NSString *)v { [self setObject:v forKey:@#key]; }

#pragma mark - WCRefine 界面圆角板块完整还原（162 个配置键）

WCR_BOOL(globalCornerEnabled, globalCornerEnabled, YES)
WCR_DOUBLE(globalCornerRadius, globalCornerRadius, 24.0)
WCR_DOUBLE(globalCornerMargin, globalCornerMargin, 18.0)
WCR_DOUBLE(globalCornerSpacing, globalCornerSpacing, 6.0)
WCR_DOUBLE(globalCornerStroke, globalCornerStroke, 0.0)
WCR_STRING(globalCornerStrokeStyle, globalCornerStrokeStyle, @"continuous")
WCR_STRING(globalCornerStrokeColorLight, globalCornerStrokeColorLight, @"#E5E5EA")
WCR_STRING(globalCornerStrokeColorDark, globalCornerStrokeColorDark, @"#3A3A3C")
WCR_STRING(globalCornerBackgroundColorLight, globalCornerBackgroundColorLight, @"#FFFFFF")
WCR_STRING(globalCornerBackgroundColorDark, globalCornerBackgroundColorDark, @"#1C1C1E")
WCR_BOOL(globalCornerPinButtonV2, globalCornerPinButtonV2, NO)
WCR_BOOL(homepageCornerEnabled, homepageCornerEnabled, YES)
WCR_BOOL(mainFrameCornerEnabled, mainFrameCornerEnabled, YES)
WCR_BOOL(discoverPageCornerEnabled, discoverPageCornerEnabled, YES)
WCR_BOOL(myPageCornerEnabled, myPageCornerEnabled, NO)
WCR_BOOL(friendProfileCornerEnabled, friendProfileCornerEnabled, NO)
WCR_BOOL(tpModeCornerEnabled, tpModeCornerEnabled, NO)
WCR_BOOL(appearanceUsesGlobalCorners, appearanceUsesGlobalCorners, YES)
WCR_BOOL(profileFollowGlobalCornerEnabled, profileFollowGlobalCornerEnabled, YES)
WCR_BOOL(profileCornerRadiusEnabled, profileCornerRadiusEnabled, YES)
WCR_BOOL(mainFrameSpacingUnifyEnabled, mainFrameSpacingUnifyEnabled, YES)
WCR_BOOL(belowPinnedUsesGlobalCard, belowPinnedUsesGlobalCard, YES)
WCR_DOUBLE(belowPinnedSectionHeight, belowPinnedSectionHeight, 8.0)
WCR_DOUBLE(belowPinnedContentGap, belowPinnedContentGap, 6.0)
WCR_DOUBLE(pinnedTopSpacing, pinnedTopSpacing, 6.0)
WCR_DOUBLE(belowPinnedSpacing, belowPinnedSpacing, 6.0)
WCR_BOOL(avatarCornerEnabled, avatarCornerEnabled, YES)
WCR_DOUBLE(avatarCornerRadius, avatarCornerRadius, 100.0)
WCR_DOUBLE(avatarCornerScale, avatarCornerScale, 1.0)
WCR_BOOL(avatarCornerScaleEnabled, avatarCornerScaleEnabled, NO)
WCR_STRING(avatarCornerScaleSceneFilter, avatarCornerScaleSceneFilter, @"all")
WCR_BOOL(avatarCornerBorderEnabled, avatarCornerBorderEnabled, NO)
WCR_DOUBLE(avatarCornerBorderSize, avatarCornerBorderSize, 1.0)
WCR_STRING(avatarCornerBorderColorLight, avatarCornerBorderColorLight, @"#D9D9D9")
WCR_STRING(avatarCornerBorderColorDark, avatarCornerBorderColorDark, @"#3F3F41")
WCR_BOOL(avatarCornerChatPageEnabled, avatarCornerChatPageEnabled, NO)
WCR_DOUBLE(avatarCornerChatPageRadius, avatarCornerChatPageRadius, 22.0)
WCR_BOOL(avatarCornerChatPageBorderEnabled, avatarCornerChatPageBorderEnabled, NO)
WCR_DOUBLE(avatarCornerChatPageBorderSize, avatarCornerChatPageBorderSize, 1.0)
WCR_STRING(avatarCornerChatPageBorderColorLight, avatarCornerChatPageBorderColorLight, @"#D9D9D9")
WCR_STRING(avatarCornerChatPageBorderColorDark, avatarCornerChatPageBorderColorDark, @"#3F3F41")
WCR_DOUBLE(avatarCornerProfileScale, avatarCornerProfileScale, 1.0)
WCR_BOOL(chatBubbleCornerEnabled, chatBubbleCornerEnabled, NO)
WCR_DOUBLE(chatBubbleCornerRadius, chatBubbleCornerRadius, 16.0)
WCR_DOUBLE(chatBubbleCornerBorderSize, chatBubbleCornerBorderSize, 0.0)
WCR_STRING(chatBubbleCornerBorderColorLight, chatBubbleCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(chatBubbleCornerBorderColorDark, chatBubbleCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(chatBubbleArrowHidden, chatBubbleArrowHidden, NO)
WCR_BOOL(chatImageCornerEnabled, chatImageCornerEnabled, NO)
WCR_DOUBLE(chatImageCornerRadius, chatImageCornerRadius, 12.0)
WCR_DOUBLE(chatImageCornerBorderSize, chatImageCornerBorderSize, 0.0)
WCR_STRING(chatImageCornerBorderColorLight, chatImageCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(chatImageCornerBorderColorDark, chatImageCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(chatTimeRoundCornerEnabled, chatTimeRoundCornerEnabled, NO)
WCR_DOUBLE(chatTimeRoundCornerRadius, chatTimeRoundCornerRadius, 8.0)
WCR_DOUBLE(chatTimeRoundCornerBorderSize, chatTimeRoundCornerBorderSize, 0.0)
WCR_STRING(chatTimeRoundCornerBorderColorLight, chatTimeRoundCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(chatTimeRoundCornerBorderColorDark, chatTimeRoundCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(searchCornerEnabled, searchCornerEnabled, YES)
WCR_DOUBLE(searchCornerRadius, searchCornerRadius, 10.0)
WCR_DOUBLE(searchCornerMargin, searchCornerMargin, 8.0)
WCR_DOUBLE(searchCornerBorderSize, searchCornerBorderSize, 0.0)
WCR_STRING(searchCornerBorderColorLight, searchCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(searchCornerBorderColorDark, searchCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(inputCornerEnabled, inputCornerEnabled, YES)
WCR_DOUBLE(inputCornerRadius, inputCornerRadius, 18.0)
WCR_DOUBLE(inputCornerBorderSize, inputCornerBorderSize, 0.0)
WCR_STRING(inputCornerBorderColorLight, inputCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(inputCornerBorderColorDark, inputCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(inputCornerBoxTransparencyEnabled, inputCornerBoxTransparencyEnabled, NO)
WCR_DOUBLE(inputCornerBoxTransparencyAlpha, inputCornerBoxTransparencyAlpha, 1.0)
WCR_BOOL(menuCornerEnabled, menuCornerEnabled, YES)
WCR_DOUBLE(menuCornerRadius, menuCornerRadius, 14.0)
WCR_DOUBLE(menuCornerBorderSize, menuCornerBorderSize, 0.0)
WCR_STRING(menuCornerBorderColorLight, menuCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(menuCornerBorderColorDark, menuCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(plusMenuCornerEnabled, plusMenuCornerEnabled, YES)
WCR_DOUBLE(plusMenuCornerRadius, plusMenuCornerRadius, 16.0)
WCR_BOOL(mainFrameSwipeMenuCornerEnabled, mainFrameSwipeMenuCornerEnabled, NO)
WCR_DOUBLE(mainFrameSwipeMenuCornerRadius, mainFrameSwipeMenuCornerRadius, 12.0)
WCR_BOOL(topbarCornerEnabled, topbarCornerEnabled, NO)
WCR_DOUBLE(topbarCornerRadius, topbarCornerRadius, 16.0)
WCR_BOOL(topbarCornerTopFlatEnabled, topbarCornerTopFlatEnabled, YES)
WCR_DOUBLE(topbarCornerBorderSize, topbarCornerBorderSize, 0.0)
WCR_STRING(topbarCornerBorderColorLight, topbarCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(topbarCornerBorderColorDark, topbarCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(toolbarCornerEnabled, toolbarCornerEnabled, NO)
WCR_DOUBLE(toolbarCornerRadius, toolbarCornerRadius, 16.0)
WCR_BOOL(toolbarCornerBottomFlatEnabled, toolbarCornerBottomFlatEnabled, YES)
WCR_DOUBLE(toolbarCornerBorderSize, toolbarCornerBorderSize, 0.0)
WCR_STRING(toolbarCornerBorderColorLight, toolbarCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(toolbarCornerBorderColorDark, toolbarCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(systemPopupCornerEnabled, systemPopupCornerEnabled, NO)
WCR_DOUBLE(systemPopupCornerRadius, systemPopupCornerRadius, 14.0)
WCR_DOUBLE(systemPopupCornerBorderSize, systemPopupCornerBorderSize, 0.0)
WCR_STRING(systemPopupCornerBorderColorLight, systemPopupCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(systemPopupCornerBorderColorDark, systemPopupCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(systemNoticeCornerEnabled, systemNoticeCornerEnabled, NO)
WCR_DOUBLE(systemNoticeCornerRadius, systemNoticeCornerRadius, 12.0)
WCR_DOUBLE(systemNoticeCornerBorderSize, systemNoticeCornerBorderSize, 0.0)
WCR_STRING(systemNoticeCornerBorderColorLight, systemNoticeCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(systemNoticeCornerBorderColorDark, systemNoticeCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(systemMessageCornerEnabled, systemMessageCornerEnabled, NO)
WCR_DOUBLE(systemMessageCornerRadius, systemMessageCornerRadius, 12.0)
WCR_DOUBLE(systemMessageCornerBorderSize, systemMessageCornerBorderSize, 0.0)
WCR_STRING(systemMessageCornerBorderColorLight, systemMessageCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(systemMessageCornerBorderColorDark, systemMessageCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(emojiCornerEnabled, emojiCornerEnabled, NO)
WCR_DOUBLE(emojiCornerRadius, emojiCornerRadius, 8.0)
WCR_DOUBLE(emojiCornerBorderSize, emojiCornerBorderSize, 0.0)
WCR_STRING(emojiCornerBorderColorLight, emojiCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(emojiCornerBorderColorDark, emojiCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(profileCornerEnabled, profileCornerEnabled, YES)
WCR_DOUBLE(profileCornerRadius, profileCornerRadius, 16.0)
WCR_DOUBLE(profileCornerMargin, profileCornerMargin, 10.0)
WCR_DOUBLE(profileAvatarCornerRadius, profileAvatarCornerRadius, 100.0)
WCR_BOOL(profileAvatarCornerOverrideEnabled, profileAvatarCornerOverrideEnabled, NO)
WCR_DOUBLE(chatAvatarProfileCardAvatarCornerRadius, chatAvatarProfileCardAvatarCornerRadius, 100.0)
WCR_BOOL(finderCornerEnabled, finderCornerEnabled, NO)
WCR_DOUBLE(finderCornerRadius, finderCornerRadius, 12.0)
WCR_DOUBLE(finderCornerBorderSize, finderCornerBorderSize, 0.0)
WCR_STRING(finderCornerBorderColorLight, finderCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(finderCornerBorderColorDark, finderCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(serviceCornerEnabled, serviceCornerEnabled, NO)
WCR_DOUBLE(serviceCornerRadius, serviceCornerRadius, 12.0)
WCR_DOUBLE(serviceCornerBorderSize, serviceCornerBorderSize, 0.0)
WCR_STRING(serviceCornerBorderColorLight, serviceCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(serviceCornerBorderColorDark, serviceCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(momentCornerEnabled, momentCornerEnabled, NO)
WCR_DOUBLE(momentCornerRadius, momentCornerRadius, 12.0)
WCR_DOUBLE(momentCornerBorderSize, momentCornerBorderSize, 0.0)
WCR_STRING(momentCornerBorderColorLight, momentCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(momentCornerBorderColorDark, momentCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(momentCornerUnifiedEnabled, momentCornerUnifiedEnabled, NO)
WCR_BOOL(momentOperateMenuCornerEnabled, momentOperateMenuCornerEnabled, NO)
WCR_BOOL(msgReferCornerEnabled, msgReferCornerEnabled, NO)
WCR_DOUBLE(msgReferCornerRadius, msgReferCornerRadius, 10.0)
WCR_DOUBLE(msgReferCornerBorderSize, msgReferCornerBorderSize, 0.0)
WCR_STRING(msgReferCornerBorderColorLight, msgReferCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(msgReferCornerBorderColorDark, msgReferCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(imeKeyboardCornerEnabled, imeKeyboardCornerEnabled, NO)
WCR_DOUBLE(imeKeyboardCornerRadius, imeKeyboardCornerRadius, 12.0)
WCR_DOUBLE(imeKeyboardCornerBorderSize, imeKeyboardCornerBorderSize, 0.0)
WCR_STRING(imeKeyboardCornerBorderColorLight, imeKeyboardCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(imeKeyboardCornerBorderColorDark, imeKeyboardCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(quickReplyMsgCornerEnabled, quickReplyMsgCornerEnabled, NO)
WCR_DOUBLE(quickReplyMsgCornerRadius, quickReplyMsgCornerRadius, 10.0)
WCR_DOUBLE(quickReplyMsgCornerBorderSize, quickReplyMsgCornerBorderSize, 0.0)
WCR_STRING(quickReplyMsgCornerBorderColorLight, quickReplyMsgCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(quickReplyMsgCornerBorderColorDark, quickReplyMsgCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(sendPublishButtonCornerEnabled, sendPublishButtonCornerEnabled, NO)
WCR_DOUBLE(sendPublishButtonCornerRadius, sendPublishButtonCornerRadius, 10.0)
WCR_DOUBLE(sendPublishButtonCornerBorderSize, sendPublishButtonCornerBorderSize, 0.0)
WCR_STRING(sendPublishButtonCornerBorderColorLight, sendPublishButtonCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(sendPublishButtonCornerBorderColorDark, sendPublishButtonCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(voiceTranslateCornerEnabled, voiceTranslateCornerEnabled, NO)
WCR_DOUBLE(voiceTranslateCornerRadius, voiceTranslateCornerRadius, 10.0)
WCR_DOUBLE(voiceTranslateCornerBorderSize, voiceTranslateCornerBorderSize, 0.0)
WCR_STRING(voiceTranslateCornerBorderColorLight, voiceTranslateCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(voiceTranslateCornerBorderColorDark, voiceTranslateCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(chatLocationCornerEnabled, chatLocationCornerEnabled, NO)
WCR_BOOL(chatFileCornerEnabled, chatFileCornerEnabled, NO)

- (NSArray<NSString *> *)globalCornerCustomExcludedVCClassNames {
    id o = [self objectForKey:@"globalCornerCustomExcludedVCClassNames" def:nil];
    return [o isKindOfClass:[NSArray class]] ? o : @[];
}

- (void)setGlobalCornerCustomExcludedVCClassNames:(NSArray<NSString *> *)v {
    [self setObject:v forKey:@"globalCornerCustomExcludedVCClassNames"];
}

WCR_BOOL(profileCardBeautifyEnabled, profileCardBeautifyEnabled, YES)
WCR_DOUBLE(profileCardCardAlpha, profileCardCardAlpha, 1.0)
WCR_DOUBLE(profileCardBackgroundImageAlpha, profileCardBackgroundImageAlpha, 1.0)
WCR_STRING(profileCardBackgroundImagePath, profileCardBackgroundImagePath, @"")
WCR_STRING(profileCardBackgroundLightColor, profileCardBackgroundLightColor, @"#F2F2F7")
WCR_STRING(profileCardBackgroundDarkColor, profileCardBackgroundDarkColor, @"#000000")
WCR_STRING(profileCardNameLightColor, profileCardNameLightColor, @"#111111")
WCR_STRING(profileCardNameDarkColor, profileCardNameDarkColor, @"#F2F2F7")
WCR_STRING(profileCardSignatureLightColor, profileCardSignatureLightColor, @"#8E8E93")
WCR_STRING(profileCardSignatureDarkColor, profileCardSignatureDarkColor, @"#8E8E93")
WCR_BOOL(profileCardWechatIDHiddenByDefault, profileCardWechatIDHiddenByDefault, NO)
WCR_BOOL(msgBannerBeautifyEnabled, msgBannerBeautifyEnabled, NO)
WCR_DOUBLE(msgBannerHeight, msgBannerHeight, 70.0)
WCR_DOUBLE(msgBannerWidth, msgBannerWidth, 0.0)               // 0 = 跟随系统
WCR_DOUBLE(msgBannerExtraMargin, msgBannerExtraMargin, 0.0)
WCR_DOUBLE(msgBannerStaySeconds, msgBannerStaySeconds, 3.0)
WCR_DOUBLE(msgBannerMaxTextLength, msgBannerMaxTextLength, 0.0) // 0 = 不截断
WCR_STRING(msgBannerMaxTextOverflowSuffix, msgBannerMaxTextOverflowSuffix, @"…")
WCR_BOOL(msgBannerBgUseImageBackground, msgBannerBgUseImageBackground, NO)
WCR_STRING(msgBannerBgImageFolder, msgBannerBgImageFolder, @"")
WCR_DOUBLE(msgBannerBgImageAlpha, msgBannerBgImageAlpha, 1.0)
WCR_DOUBLE(msgBannerBgImageOffsetX, msgBannerBgImageOffsetX, 0.0)
WCR_DOUBLE(msgBannerBgImageOffsetY, msgBannerBgImageOffsetY, 0.0)
WCR_BOOL(msgBannerBgColorEnabled, msgBannerBgColorEnabled, NO)
WCR_STRING(msgBannerBgColorLight, msgBannerBgColorLight, @"#FFFFFF")
WCR_STRING(msgBannerBgColorDark, msgBannerBgColorDark, @"#1C1C1E")
WCR_BOOL(msgBannerFrostColorEnabled, msgBannerFrostColorEnabled, YES)
WCR_STRING(msgBannerFrostColorLight, msgBannerFrostColorLight, @"#F7F7F7")
WCR_STRING(msgBannerFrostColorDark, msgBannerFrostColorDark, @"#2C2C2E")
WCR_BOOL(msgBannerNicknameColorEnabled, msgBannerNicknameColorEnabled, NO)
WCR_STRING(msgBannerNicknameColorLight, msgBannerNicknameColorLight, @"#111111")
WCR_STRING(msgBannerNicknameColorDark, msgBannerNicknameColorDark, @"#F2F2F7")
WCR_BOOL(msgBannerContentColorEnabled, msgBannerContentColorEnabled, NO)
WCR_STRING(msgBannerContentColorLight, msgBannerContentColorLight, @"#3A3A3C")
WCR_STRING(msgBannerContentColorDark, msgBannerContentColorDark, @"#D1D1D6")
WCR_DOUBLE(plusMenuBorderSize, plusMenuBorderSize, 0.0)
WCR_STRING(plusMenuBorderColorLight, plusMenuBorderColorLight, @"#E5E5EA")
WCR_STRING(plusMenuBorderColorDark, plusMenuBorderColorDark, @"#3A3A3C")
WCR_BOOL(menuUseImageBackground, menuUseImageBackground, NO)
WCR_STRING(menuBackgroundImageFolder, menuBackgroundImageFolder, @"")
WCR_DOUBLE(menuBackgroundViewAlpha, menuBackgroundViewAlpha, 1.0)
WCR_BOOL(menuSizeEnabled, menuSizeEnabled, NO)
WCR_DOUBLE(menuWidth, menuWidth, 0.0)
WCR_DOUBLE(menuMaxCountPerLine, menuMaxCountPerLine, 0.0)
WCR_BOOL(menuColorEnabled, menuColorEnabled, NO)
WCR_STRING(menuColorLight, menuColorLight, @"#FFFFFF")
WCR_STRING(menuColorDark, menuColorDark, @"#1C1C1E")
WCR_BOOL(menuTextColorEnabled, menuTextColorEnabled, NO)
WCR_STRING(menuTextColorLight, menuTextColorLight, @"#111111")
WCR_STRING(menuTextColorDark, menuTextColorDark, @"#F2F2F7")
WCR_BOOL(menuIconColorEnabled, menuIconColorEnabled, NO)
WCR_STRING(menuIconColorLight, menuIconColorLight, @"#111111")
WCR_STRING(menuIconColorDark, menuIconColorDark, @"#F2F2F7")
WCR_BOOL(menuTextCenterEnabled, menuTextCenterEnabled, NO)

WCR_BOOL(floatingTabBarEnabled, floatingTabBarEnabled, YES)
WCR_BOOL(cardShadowEnabled, cardShadowEnabled, YES)

@end
