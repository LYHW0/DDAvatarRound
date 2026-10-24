//
//  LYHWConfig.m
//  LYHW
//
//  基于 LYHW 2.1-9 逆向分析完整还原的配置实现
//  162 个圆角相关配置键，使用宏简化代码
//

#import "LYHWConfig.h"
#import <notify.h>

NSString * const LYHWSettingsChangedNotification = @"com.lyhw.settings_changed";

static NSString * const kWRCSuiteName = @"com.lyhw.LYHW";

@interface LYHWConfig ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@end

@implementation LYHWConfig

+ (instancetype)shared {
    static LYHWConfig *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[LYHWConfig alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:kWRCSuiteName];
        // 从旧版配置迁移一次
        if (![_defaults boolForKey:@"__LYHWMigrated"]) {
            NSDictionary *old = [[NSUserDefaults standardUserDefaults] persistentDomainForName:[@"com.qimiao.WC" stringByAppendingString:@"Refine.rebuild"]];
            for (NSString *k in old) if (![_defaults objectForKey:k]) [_defaults setObject:old[k] forKey:k];
            [_defaults setBool:YES forKey:@"__LYHWMigrated"];
        }

        __weak typeof(self) weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:LYHWSettingsChangedNotification
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

- (NSDictionary *)exportAll {
    NSMutableDictionary *d = [[self.defaults persistentDomainForName:kWRCSuiteName] mutableCopy] ?: [NSMutableDictionary dictionary];
    [d removeObjectForKey:@"__LYHWMigrated"];
    return d;
}

- (NSInteger)importAll:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return -1;
    NSInteger n = 0;
    for (NSString *k in dict) {
        id v = dict[k];
        if (![k isKindOfClass:[NSString class]]) continue;
        if ([v isKindOfClass:[NSNumber class]] || [v isKindOfClass:[NSString class]]) { [self.defaults setObject:v forKey:k]; n++; }
    }
    [self.defaults synchronize];
    return n;
}

#pragma mark - 取值便捷宏

#define LYHW_BOOL(prop, key, defv) \
- (BOOL)prop { return [self objectForKey:@#key def:@(defv)] ? [[self objectForKey:@#key def:@(defv)] boolValue] : defv; } \
- (void)set##prop:(BOOL)v { [self setObject:@(v) forKey:@#key]; }

#define LYHW_DOUBLE(prop, key, defv) \
- (double)prop { id o = [self objectForKey:@#key def:nil]; return o ? [o doubleValue] : defv; } \
- (void)set##prop:(double)v { [self setObject:@(v) forKey:@#key]; }

#define LYHW_STRING(prop, key, defv) \
- (NSString *)prop { id o = [self objectForKey:@#key def:nil]; return o ?: defv; } \
- (void)set##prop:(NSString *)v { [self setObject:v forKey:@#key]; }

#pragma mark - LYHW 界面圆角板块完整还原（162 个配置键）

LYHW_BOOL(globalCornerEnabled, globalCornerEnabled, YES)
LYHW_DOUBLE(globalCornerRadius, globalCornerRadius, 24.0)
LYHW_DOUBLE(globalCornerMargin, globalCornerMargin, 18.0)
LYHW_DOUBLE(globalCornerSpacing, globalCornerSpacing, 6.0)
LYHW_DOUBLE(globalCornerStroke, globalCornerStroke, 0.0)
LYHW_STRING(globalCornerStrokeStyle, globalCornerStrokeStyle, @"continuous")
LYHW_STRING(globalCornerStrokeColorLight, globalCornerStrokeColorLight, @"#E5E5EA")
LYHW_STRING(globalCornerStrokeColorDark, globalCornerStrokeColorDark, @"#3A3A3C")
LYHW_STRING(globalCornerBackgroundColorLight, globalCornerBackgroundColorLight, @"#FFFFFF")
LYHW_STRING(globalCornerBackgroundColorDark, globalCornerBackgroundColorDark, @"#1C1C1E")
LYHW_BOOL(globalCornerPinButtonV2, globalCornerPinButtonV2, NO)
LYHW_BOOL(homepageCornerEnabled, homepageCornerEnabled, YES)
LYHW_BOOL(mainFrameCornerEnabled, mainFrameCornerEnabled, YES)
LYHW_BOOL(settingPageCornerEnabled, settingPageCornerEnabled, YES)
LYHW_BOOL(discoverPageCornerEnabled, discoverPageCornerEnabled, YES)
LYHW_BOOL(myPageCornerEnabled, myPageCornerEnabled, NO)
LYHW_BOOL(friendProfileCornerEnabled, friendProfileCornerEnabled, NO)
LYHW_BOOL(tpModeCornerEnabled, tpModeCornerEnabled, NO)
LYHW_BOOL(appearanceUsesGlobalCorners, appearanceUsesGlobalCorners, YES)
LYHW_BOOL(profileFollowGlobalCornerEnabled, profileFollowGlobalCornerEnabled, YES)
LYHW_BOOL(profileCornerRadiusEnabled, profileCornerRadiusEnabled, YES)
LYHW_BOOL(mainFrameSpacingUnifyEnabled, mainFrameSpacingUnifyEnabled, YES)
LYHW_BOOL(belowPinnedUsesGlobalCard, belowPinnedUsesGlobalCard, YES)
LYHW_DOUBLE(belowPinnedSectionHeight, belowPinnedSectionHeight, 8.0)
LYHW_DOUBLE(belowPinnedContentGap, belowPinnedContentGap, 6.0)
LYHW_DOUBLE(pinnedTopSpacing, pinnedTopSpacing, 6.0)
LYHW_DOUBLE(belowPinnedSpacing, belowPinnedSpacing, 6.0)
LYHW_BOOL(avatarCornerEnabled, avatarCornerEnabled, YES)
LYHW_DOUBLE(avatarCornerRadius, avatarCornerRadius, 100.0)
LYHW_DOUBLE(avatarCornerScale, avatarCornerScale, 1.0)
LYHW_BOOL(avatarCornerScaleEnabled, avatarCornerScaleEnabled, NO)
LYHW_STRING(avatarCornerScaleSceneFilter, avatarCornerScaleSceneFilter, @"all")
LYHW_BOOL(avatarCornerBorderEnabled, avatarCornerBorderEnabled, NO)
LYHW_DOUBLE(avatarCornerBorderSize, avatarCornerBorderSize, 1.0)
LYHW_STRING(avatarCornerBorderColorLight, avatarCornerBorderColorLight, @"#D9D9D9")
LYHW_STRING(avatarCornerBorderColorDark, avatarCornerBorderColorDark, @"#3F3F41")
LYHW_BOOL(avatarCornerChatPageEnabled, avatarCornerChatPageEnabled, NO)
LYHW_DOUBLE(avatarCornerChatPageRadius, avatarCornerChatPageRadius, 22.0)
LYHW_BOOL(avatarCornerChatPageBorderEnabled, avatarCornerChatPageBorderEnabled, NO)
LYHW_DOUBLE(avatarCornerChatPageBorderSize, avatarCornerChatPageBorderSize, 1.0)
LYHW_STRING(avatarCornerChatPageBorderColorLight, avatarCornerChatPageBorderColorLight, @"#D9D9D9")
LYHW_STRING(avatarCornerChatPageBorderColorDark, avatarCornerChatPageBorderColorDark, @"#3F3F41")
LYHW_DOUBLE(avatarCornerProfileScale, avatarCornerProfileScale, 1.0)
LYHW_BOOL(chatBubbleCornerEnabled, chatBubbleCornerEnabled, NO)
LYHW_DOUBLE(chatBubbleCornerRadius, chatBubbleCornerRadius, 16.0)
LYHW_DOUBLE(chatBubbleCornerBorderSize, chatBubbleCornerBorderSize, 0.0)
LYHW_STRING(chatBubbleCornerBorderColorLight, chatBubbleCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatBubbleCornerBorderColorDark, chatBubbleCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatBubbleArrowHidden, chatBubbleArrowHidden, NO)
LYHW_BOOL(chatImageCornerEnabled, chatImageCornerEnabled, NO)
LYHW_DOUBLE(chatImageCornerRadius, chatImageCornerRadius, 12.0)
LYHW_DOUBLE(chatImageCornerBorderSize, chatImageCornerBorderSize, 0.0)
LYHW_STRING(chatImageCornerBorderColorLight, chatImageCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatImageCornerBorderColorDark, chatImageCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatTimeRoundCornerEnabled, chatTimeRoundCornerEnabled, NO)
LYHW_DOUBLE(chatTimeRoundCornerRadius, chatTimeRoundCornerRadius, 8.0)
LYHW_DOUBLE(chatTimeRoundCornerBorderSize, chatTimeRoundCornerBorderSize, 0.0)
LYHW_STRING(chatTimeRoundCornerBorderColorLight, chatTimeRoundCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatTimeRoundCornerBorderColorDark, chatTimeRoundCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(searchCornerEnabled, searchCornerEnabled, YES)
LYHW_DOUBLE(searchCornerRadius, searchCornerRadius, 18.0)
LYHW_DOUBLE(searchCornerMargin, searchCornerMargin, 8.0)
LYHW_DOUBLE(searchCornerBorderSize, searchCornerBorderSize, 0.0)
LYHW_STRING(searchCornerBorderColorLight, searchCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(searchCornerBorderColorDark, searchCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(inputCornerEnabled, inputCornerEnabled, YES)
LYHW_DOUBLE(inputCornerRadius, inputCornerRadius, 18.0)
LYHW_DOUBLE(inputCornerBorderSize, inputCornerBorderSize, 0.0)
LYHW_STRING(inputCornerBorderColorLight, inputCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(inputCornerBorderColorDark, inputCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(inputCornerBoxTransparencyEnabled, inputCornerBoxTransparencyEnabled, NO)
LYHW_DOUBLE(inputCornerBoxTransparencyAlpha, inputCornerBoxTransparencyAlpha, 1.0)
LYHW_BOOL(menuCornerEnabled, menuCornerEnabled, YES)
LYHW_DOUBLE(menuCornerRadius, menuCornerRadius, 22.0)
LYHW_DOUBLE(menuCornerBorderSize, menuCornerBorderSize, 0.0)
LYHW_STRING(menuCornerBorderColorLight, menuCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(menuCornerBorderColorDark, menuCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(plusMenuCornerEnabled, plusMenuCornerEnabled, YES)
LYHW_DOUBLE(plusMenuCornerRadius, plusMenuCornerRadius, 22.0)
LYHW_BOOL(mainFrameSwipeMenuCornerEnabled, mainFrameSwipeMenuCornerEnabled, NO)
LYHW_DOUBLE(mainFrameSwipeMenuCornerRadius, mainFrameSwipeMenuCornerRadius, 12.0)
LYHW_BOOL(topbarCornerEnabled, topbarCornerEnabled, NO)
LYHW_DOUBLE(topbarCornerRadius, topbarCornerRadius, 34.0)
LYHW_BOOL(topbarCornerTopFlatEnabled, topbarCornerTopFlatEnabled, YES)
LYHW_DOUBLE(topbarCornerBorderSize, topbarCornerBorderSize, 0.0)
LYHW_STRING(topbarCornerBorderColorLight, topbarCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(topbarCornerBorderColorDark, topbarCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(toolbarCornerEnabled, toolbarCornerEnabled, NO)
LYHW_DOUBLE(toolbarCornerRadius, toolbarCornerRadius, 24.0)
LYHW_BOOL(toolbarCornerBottomFlatEnabled, toolbarCornerBottomFlatEnabled, YES)
LYHW_DOUBLE(toolbarCornerBorderSize, toolbarCornerBorderSize, 0.0)
LYHW_STRING(toolbarCornerBorderColorLight, toolbarCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(toolbarCornerBorderColorDark, toolbarCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(systemPopupCornerEnabled, systemPopupCornerEnabled, NO)
LYHW_DOUBLE(systemPopupCornerRadius, systemPopupCornerRadius, 14.0)
LYHW_DOUBLE(systemPopupCornerBorderSize, systemPopupCornerBorderSize, 0.0)
LYHW_STRING(systemPopupCornerBorderColorLight, systemPopupCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(systemPopupCornerBorderColorDark, systemPopupCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(systemNoticeCornerEnabled, systemNoticeCornerEnabled, NO)
LYHW_DOUBLE(systemNoticeCornerRadius, systemNoticeCornerRadius, 12.0)
LYHW_DOUBLE(systemNoticeCornerBorderSize, systemNoticeCornerBorderSize, 0.0)
LYHW_STRING(systemNoticeCornerBorderColorLight, systemNoticeCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(systemNoticeCornerBorderColorDark, systemNoticeCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(systemMessageCornerEnabled, systemMessageCornerEnabled, NO)
LYHW_DOUBLE(systemMessageCornerRadius, systemMessageCornerRadius, 12.0)
LYHW_DOUBLE(systemMessageCornerBorderSize, systemMessageCornerBorderSize, 0.0)
LYHW_STRING(systemMessageCornerBorderColorLight, systemMessageCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(systemMessageCornerBorderColorDark, systemMessageCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(emojiCornerEnabled, emojiCornerEnabled, NO)
LYHW_DOUBLE(emojiCornerRadius, emojiCornerRadius, 8.0)
LYHW_DOUBLE(emojiCornerBorderSize, emojiCornerBorderSize, 0.0)
LYHW_STRING(emojiCornerBorderColorLight, emojiCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(emojiCornerBorderColorDark, emojiCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(profileCornerEnabled, profileCornerEnabled, YES)
LYHW_DOUBLE(profileCornerRadius, profileCornerRadius, 16.0)
LYHW_DOUBLE(profileCornerMargin, profileCornerMargin, 10.0)
LYHW_DOUBLE(profileAvatarCornerRadius, profileAvatarCornerRadius, 100.0)
LYHW_BOOL(profileAvatarCornerOverrideEnabled, profileAvatarCornerOverrideEnabled, NO)
LYHW_DOUBLE(chatAvatarProfileCardAvatarCornerRadius, chatAvatarProfileCardAvatarCornerRadius, 100.0)
LYHW_BOOL(finderCornerEnabled, finderCornerEnabled, NO)
LYHW_DOUBLE(finderCornerRadius, finderCornerRadius, 12.0)
LYHW_DOUBLE(finderCornerBorderSize, finderCornerBorderSize, 0.0)
LYHW_STRING(finderCornerBorderColorLight, finderCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(finderCornerBorderColorDark, finderCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(serviceCornerEnabled, serviceCornerEnabled, NO)
LYHW_DOUBLE(serviceCornerRadius, serviceCornerRadius, 12.0)
LYHW_DOUBLE(serviceCornerBorderSize, serviceCornerBorderSize, 0.0)
LYHW_STRING(serviceCornerBorderColorLight, serviceCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(serviceCornerBorderColorDark, serviceCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(momentCornerEnabled, momentCornerEnabled, NO)
LYHW_DOUBLE(momentCornerRadius, momentCornerRadius, 12.0)
LYHW_DOUBLE(momentCornerBorderSize, momentCornerBorderSize, 0.0)
LYHW_STRING(momentCornerBorderColorLight, momentCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(momentCornerBorderColorDark, momentCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(momentCornerUnifiedEnabled, momentCornerUnifiedEnabled, NO)
LYHW_BOOL(momentOperateMenuCornerEnabled, momentOperateMenuCornerEnabled, NO)
LYHW_BOOL(msgReferCornerEnabled, msgReferCornerEnabled, NO)
LYHW_DOUBLE(msgReferCornerRadius, msgReferCornerRadius, 10.0)
LYHW_DOUBLE(msgReferCornerBorderSize, msgReferCornerBorderSize, 0.0)
LYHW_STRING(msgReferCornerBorderColorLight, msgReferCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(msgReferCornerBorderColorDark, msgReferCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(imeKeyboardCornerEnabled, imeKeyboardCornerEnabled, NO)
LYHW_DOUBLE(imeKeyboardCornerRadius, imeKeyboardCornerRadius, 12.0)
LYHW_DOUBLE(imeKeyboardCornerBorderSize, imeKeyboardCornerBorderSize, 0.0)
LYHW_STRING(imeKeyboardCornerBorderColorLight, imeKeyboardCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(imeKeyboardCornerBorderColorDark, imeKeyboardCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(quickReplyMsgCornerEnabled, quickReplyMsgCornerEnabled, NO)
LYHW_DOUBLE(quickReplyMsgCornerRadius, quickReplyMsgCornerRadius, 10.0)
LYHW_DOUBLE(quickReplyMsgCornerBorderSize, quickReplyMsgCornerBorderSize, 0.0)
LYHW_STRING(quickReplyMsgCornerBorderColorLight, quickReplyMsgCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(quickReplyMsgCornerBorderColorDark, quickReplyMsgCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(sendPublishButtonCornerEnabled, sendPublishButtonCornerEnabled, NO)
LYHW_DOUBLE(sendPublishButtonCornerRadius, sendPublishButtonCornerRadius, 10.0)
LYHW_DOUBLE(sendPublishButtonCornerBorderSize, sendPublishButtonCornerBorderSize, 0.0)
LYHW_STRING(sendPublishButtonCornerBorderColorLight, sendPublishButtonCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(sendPublishButtonCornerBorderColorDark, sendPublishButtonCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(voiceTranslateCornerEnabled, voiceTranslateCornerEnabled, NO)
LYHW_DOUBLE(voiceTranslateCornerRadius, voiceTranslateCornerRadius, 10.0)
LYHW_DOUBLE(voiceTranslateCornerBorderSize, voiceTranslateCornerBorderSize, 0.0)
LYHW_STRING(voiceTranslateCornerBorderColorLight, voiceTranslateCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(voiceTranslateCornerBorderColorDark, voiceTranslateCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatLocationCornerEnabled, chatLocationCornerEnabled, NO)
LYHW_BOOL(chatFileCornerEnabled, chatFileCornerEnabled, NO)

- (NSArray<NSString *> *)globalCornerCustomExcludedVCClassNames {
    id o = [self objectForKey:@"globalCornerCustomExcludedVCClassNames" def:nil];
    return [o isKindOfClass:[NSArray class]] ? o : @[];
}

- (void)setGlobalCornerCustomExcludedVCClassNames:(NSArray<NSString *> *)v {
    [self setObject:v forKey:@"globalCornerCustomExcludedVCClassNames"];
}

LYHW_BOOL(profileCardBeautifyEnabled, profileCardBeautifyEnabled, YES)
LYHW_DOUBLE(profileCardCardAlpha, profileCardCardAlpha, 1.0)
LYHW_DOUBLE(profileCardBackgroundImageAlpha, profileCardBackgroundImageAlpha, 1.0)
LYHW_STRING(profileCardBackgroundImagePath, profileCardBackgroundImagePath, @"")
LYHW_STRING(profileCardBackgroundLightColor, profileCardBackgroundLightColor, @"#F2F2F7")
LYHW_STRING(profileCardBackgroundDarkColor, profileCardBackgroundDarkColor, @"#000000")
LYHW_STRING(profileCardNameLightColor, profileCardNameLightColor, @"#111111")
LYHW_STRING(profileCardNameDarkColor, profileCardNameDarkColor, @"#F2F2F7")
LYHW_STRING(profileCardSignatureLightColor, profileCardSignatureLightColor, @"#8E8E93")
LYHW_STRING(profileCardSignatureDarkColor, profileCardSignatureDarkColor, @"#8E8E93")
LYHW_BOOL(profileCardWechatIDHiddenByDefault, profileCardWechatIDHiddenByDefault, NO)
LYHW_BOOL(msgBannerBeautifyEnabled, msgBannerBeautifyEnabled, NO)
LYHW_DOUBLE(msgBannerHeight, msgBannerHeight, 70.0)
LYHW_DOUBLE(msgBannerWidth, msgBannerWidth, 0.0)               // 0 = 跟随系统
LYHW_DOUBLE(msgBannerExtraMargin, msgBannerExtraMargin, 0.0)
LYHW_DOUBLE(msgBannerStaySeconds, msgBannerStaySeconds, 3.0)
LYHW_DOUBLE(msgBannerMaxTextLength, msgBannerMaxTextLength, 0.0) // 0 = 不截断
LYHW_STRING(msgBannerMaxTextOverflowSuffix, msgBannerMaxTextOverflowSuffix, @"…")
LYHW_BOOL(msgBannerBgUseImageBackground, msgBannerBgUseImageBackground, NO)
LYHW_STRING(msgBannerBgImageFolder, msgBannerBgImageFolder, @"")
LYHW_DOUBLE(msgBannerBgImageAlpha, msgBannerBgImageAlpha, 1.0)
LYHW_DOUBLE(msgBannerBgImageOffsetX, msgBannerBgImageOffsetX, 0.0)
LYHW_DOUBLE(msgBannerBgImageOffsetY, msgBannerBgImageOffsetY, 0.0)
LYHW_BOOL(msgBannerBgColorEnabled, msgBannerBgColorEnabled, NO)
LYHW_STRING(msgBannerBgColorLight, msgBannerBgColorLight, @"#FFFFFF")
LYHW_STRING(msgBannerBgColorDark, msgBannerBgColorDark, @"#1C1C1E")
LYHW_BOOL(msgBannerFrostColorEnabled, msgBannerFrostColorEnabled, YES)
LYHW_STRING(msgBannerFrostColorLight, msgBannerFrostColorLight, @"#F7F7F7")
LYHW_STRING(msgBannerFrostColorDark, msgBannerFrostColorDark, @"#2C2C2E")
LYHW_BOOL(msgBannerNicknameColorEnabled, msgBannerNicknameColorEnabled, NO)
LYHW_STRING(msgBannerNicknameColorLight, msgBannerNicknameColorLight, @"#111111")
LYHW_STRING(msgBannerNicknameColorDark, msgBannerNicknameColorDark, @"#F2F2F7")
LYHW_BOOL(msgBannerContentColorEnabled, msgBannerContentColorEnabled, NO)
LYHW_STRING(msgBannerContentColorLight, msgBannerContentColorLight, @"#3A3A3C")
LYHW_STRING(msgBannerContentColorDark, msgBannerContentColorDark, @"#D1D1D6")
LYHW_DOUBLE(plusMenuBorderSize, plusMenuBorderSize, 0.0)
LYHW_STRING(plusMenuBorderColorLight, plusMenuBorderColorLight, @"#E5E5EA")
LYHW_STRING(plusMenuBorderColorDark, plusMenuBorderColorDark, @"#3A3A3C")
LYHW_BOOL(menuUseImageBackground, menuUseImageBackground, NO)
LYHW_STRING(menuBackgroundImageFolder, menuBackgroundImageFolder, @"")
LYHW_DOUBLE(menuBackgroundViewAlpha, menuBackgroundViewAlpha, 1.0)
LYHW_BOOL(menuSizeEnabled, menuSizeEnabled, NO)
LYHW_DOUBLE(menuWidth, menuWidth, 0.0)
LYHW_DOUBLE(menuMaxCountPerLine, menuMaxCountPerLine, 0.0)
LYHW_BOOL(menuColorEnabled, menuColorEnabled, NO)
LYHW_STRING(menuColorLight, menuColorLight, @"#FFFFFF")
LYHW_STRING(menuColorDark, menuColorDark, @"#1C1C1E")
LYHW_BOOL(menuTextColorEnabled, menuTextColorEnabled, NO)
LYHW_STRING(menuTextColorLight, menuTextColorLight, @"#111111")
LYHW_STRING(menuTextColorDark, menuTextColorDark, @"#F2F2F7")
LYHW_BOOL(menuIconColorEnabled, menuIconColorEnabled, NO)
LYHW_STRING(menuIconColorLight, menuIconColorLight, @"#111111")
LYHW_STRING(menuIconColorDark, menuIconColorDark, @"#F2F2F7")
LYHW_BOOL(menuTextCenterEnabled, menuTextCenterEnabled, NO)

LYHW_BOOL(floatingTabBarEnabled, floatingTabBarEnabled, NO)
LYHW_BOOL(cardShadowEnabled, cardShadowEnabled, YES)
LYHW_BOOL(cellTapEffectHidden, cellTapEffectHidden, NO)
LYHW_DOUBLE(myPageCornerRadius, myPageCornerRadius, 24.0)
LYHW_DOUBLE(myPageCornerMargin, myPageCornerMargin, 20.0)
LYHW_DOUBLE(cardShadowStrength, cardShadowStrength, 0.10)
LYHW_BOOL(timelineCornerEnabled, timelineCornerEnabled, YES)
LYHW_DOUBLE(timelineCornerRadius, timelineCornerRadius, 24.0)
LYHW_BOOL(timelineMediaCornerEnabled, timelineMediaCornerEnabled, YES)
LYHW_DOUBLE(timelineMediaCornerRadius, timelineMediaCornerRadius, 16.0)
LYHW_BOOL(timelineCommentCornerEnabled, timelineCommentCornerEnabled, YES)
LYHW_DOUBLE(timelineCommentCornerRadius, timelineCommentCornerRadius, 14.0)
LYHW_BOOL(forwardPickerCornerEnabled, forwardPickerCornerEnabled, YES)
LYHW_DOUBLE(forwardPickerCornerRadius, forwardPickerCornerRadius, 24.0)
LYHW_BOOL(profilePageCornerEnabled, profilePageCornerEnabled, YES)
LYHW_BOOL(groupInfoCornerEnabled, groupInfoCornerEnabled, YES)
LYHW_BOOL(servicePageCornerEnabled, servicePageCornerEnabled, YES)
LYHW_DOUBLE(servicePageCornerRadius, servicePageCornerRadius, 24.0)


#pragma mark - 全局圆角移植（规则表，68 项）
LYHW_BOOL(chatArticleCornerEnabled, chatArticleCornerEnabled, NO)
LYHW_DOUBLE(chatArticleCornerRadius, chatArticleCornerRadius, 10.0)
LYHW_DOUBLE(chatArticleCornerBorderSize, chatArticleCornerBorderSize, 0.0)
LYHW_STRING(chatArticleCornerBorderColorLight, chatArticleCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatArticleCornerBorderColorDark, chatArticleCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatCardCornerEnabled, chatCardCornerEnabled, NO)
LYHW_DOUBLE(chatCardCornerRadius, chatCardCornerRadius, 10.0)
LYHW_DOUBLE(chatCardCornerBorderSize, chatCardCornerBorderSize, 0.0)
LYHW_STRING(chatCardCornerBorderColorLight, chatCardCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatCardCornerBorderColorDark, chatCardCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatFavoriteCornerEnabled, chatFavoriteCornerEnabled, NO)
LYHW_DOUBLE(chatFavoriteCornerRadius, chatFavoriteCornerRadius, 10.0)
LYHW_DOUBLE(chatFavoriteCornerBorderSize, chatFavoriteCornerBorderSize, 0.0)
LYHW_STRING(chatFavoriteCornerBorderColorLight, chatFavoriteCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatFavoriteCornerBorderColorDark, chatFavoriteCornerBorderColorDark, @"#3A3A3C")
LYHW_DOUBLE(chatFileCornerRadius, chatFileCornerRadius, 10.0)
LYHW_DOUBLE(chatFileCornerBorderSize, chatFileCornerBorderSize, 0.0)
LYHW_STRING(chatFileCornerBorderColorLight, chatFileCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatFileCornerBorderColorDark, chatFileCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatHistoryCornerEnabled, chatHistoryCornerEnabled, NO)
LYHW_DOUBLE(chatHistoryCornerRadius, chatHistoryCornerRadius, 10.0)
LYHW_DOUBLE(chatHistoryCornerBorderSize, chatHistoryCornerBorderSize, 0.0)
LYHW_STRING(chatHistoryCornerBorderColorLight, chatHistoryCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatHistoryCornerBorderColorDark, chatHistoryCornerBorderColorDark, @"#3A3A3C")
LYHW_DOUBLE(chatLocationCornerRadius, chatLocationCornerRadius, 10.0)
LYHW_DOUBLE(chatLocationCornerBorderSize, chatLocationCornerBorderSize, 0.0)
LYHW_STRING(chatLocationCornerBorderColorLight, chatLocationCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatLocationCornerBorderColorDark, chatLocationCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatMiniProgramCornerEnabled, chatMiniProgramCornerEnabled, NO)
LYHW_DOUBLE(chatMiniProgramCornerRadius, chatMiniProgramCornerRadius, 10.0)
LYHW_DOUBLE(chatMiniProgramCornerBorderSize, chatMiniProgramCornerBorderSize, 0.0)
LYHW_STRING(chatMiniProgramCornerBorderColorLight, chatMiniProgramCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatMiniProgramCornerBorderColorDark, chatMiniProgramCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatMusicCornerEnabled, chatMusicCornerEnabled, NO)
LYHW_DOUBLE(chatMusicCornerRadius, chatMusicCornerRadius, 10.0)
LYHW_DOUBLE(chatMusicCornerBorderSize, chatMusicCornerBorderSize, 0.0)
LYHW_STRING(chatMusicCornerBorderColorLight, chatMusicCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatMusicCornerBorderColorDark, chatMusicCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatPinTipsCornerEnabled, chatPinTipsCornerEnabled, NO)
LYHW_DOUBLE(chatPinTipsCornerRadius, chatPinTipsCornerRadius, 10.0)
LYHW_DOUBLE(chatPinTipsCornerBorderSize, chatPinTipsCornerBorderSize, 0.0)
LYHW_STRING(chatPinTipsCornerBorderColorLight, chatPinTipsCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatPinTipsCornerBorderColorDark, chatPinTipsCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatRedPacketCornerEnabled, chatRedPacketCornerEnabled, NO)
LYHW_DOUBLE(chatRedPacketCornerRadius, chatRedPacketCornerRadius, 10.0)
LYHW_DOUBLE(chatRedPacketCornerBorderSize, chatRedPacketCornerBorderSize, 0.0)
LYHW_STRING(chatRedPacketCornerBorderColorLight, chatRedPacketCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatRedPacketCornerBorderColorDark, chatRedPacketCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(chatSearchThumbCornerEnabled, chatSearchThumbCornerEnabled, NO)
LYHW_DOUBLE(chatSearchThumbCornerRadius, chatSearchThumbCornerRadius, 6.0)
LYHW_DOUBLE(chatSearchThumbCornerBorderSize, chatSearchThumbCornerBorderSize, 0.0)
LYHW_STRING(chatSearchThumbCornerBorderColorLight, chatSearchThumbCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(chatSearchThumbCornerBorderColorDark, chatSearchThumbCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(favoriteCornerEnabled, favoriteCornerEnabled, NO)
LYHW_DOUBLE(favoriteCornerRadius, favoriteCornerRadius, 8.0)
LYHW_DOUBLE(favoriteCornerBorderSize, favoriteCornerBorderSize, 0.0)
LYHW_STRING(favoriteCornerBorderColorLight, favoriteCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(favoriteCornerBorderColorDark, favoriteCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(fileBrowseCornerEnabled, fileBrowseCornerEnabled, NO)
LYHW_DOUBLE(fileBrowseCornerRadius, fileBrowseCornerRadius, 8.0)
LYHW_DOUBLE(fileBrowseCornerBorderSize, fileBrowseCornerBorderSize, 0.0)
LYHW_STRING(fileBrowseCornerBorderColorLight, fileBrowseCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(fileBrowseCornerBorderColorDark, fileBrowseCornerBorderColorDark, @"#3A3A3C")
LYHW_BOOL(photoAlbumCornerEnabled, photoAlbumCornerEnabled, NO)
LYHW_DOUBLE(photoAlbumCornerRadius, photoAlbumCornerRadius, 4.0)
LYHW_DOUBLE(photoAlbumCornerBorderSize, photoAlbumCornerBorderSize, 0.0)
LYHW_STRING(photoAlbumCornerBorderColorLight, photoAlbumCornerBorderColorLight, @"#E5E5EA")
LYHW_STRING(photoAlbumCornerBorderColorDark, photoAlbumCornerBorderColorDark, @"#3A3A3C")

@end
