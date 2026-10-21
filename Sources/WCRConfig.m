//
//  WCRConfig.m
//  WCRefineRebuild
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

        // 设置界面改完 → 发通知 → 这里收到后刷新缓存，保证"改了立刻生效"
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

- (id)objectForKey:(NSString *)key def:(id)def {
    id v = [self.defaults objectForKey:key];
    if (v == nil || v == [NSNull null]) return def;
    return v;
}

- (void)setObject:(id)value forKey:(NSString *)key {
    if (value == nil) {
        [self.defaults removeObjectForKey:key];
    } else {
        [self.defaults setObject:value forKey:key];
    }
}

// ---------- 取值便捷宏 ----------
#define WCR_BOOL(prop, key, defv) \
- (BOOL)prop { return [self objectForKey:@#key def:@(defv)] ? [[self objectForKey:@#key def:@(defv)] boolValue] : defv; } \
- (void)set##prop:(BOOL)v { [self setObject:@(v) forKey:@#key]; }

#define WCR_DOUBLE(prop, key, defv) \
- (double)prop { id o = [self objectForKey:@#key def:nil]; return o ? [o doubleValue] : defv; } \
- (void)set##prop:(double)v { [self setObject:@(v) forKey:@#key]; }

#define WCR_STRING(prop, key, defv) \
- (NSString *)prop { id o = [self objectForKey:@#key def:nil]; return o ?: defv; } \
- (void)set##prop:(NSString *)v { [self setObject:v forKey:@#key]; }

// ---------------- 全局圆角 ----------------
WCR_BOOL(homepageCornerEnabled, homepageCornerEnabled, YES)
WCR_BOOL(mainFrameCornerEnabled, mainFrameCornerEnabled, YES)
WCR_BOOL(mainFrameSpacingUnifyEnabled, mainFrameSpacingUnifyEnabled, YES)
WCR_BOOL(discoverPageCornerEnabled, discoverPageCornerEnabled, YES)
WCR_BOOL(myPageCornerEnabled, myPageCornerEnabled, NO)

WCR_DOUBLE(globalCornerRadius, globalCornerRadius, 15.0)          // 二进制默认值：15
WCR_DOUBLE(globalCornerSpacing, globalCornerSpacing, 6.0)
WCR_DOUBLE(globalCornerMargin, globalCornerMargin, 10.0)
WCR_DOUBLE(globalCornerStroke, globalCornerStroke, 0.0)

WCR_STRING(globalCornerBackgroundColorLight, globalCornerBackgroundColorLight, @"#FFFFFF")
WCR_STRING(globalCornerBackgroundColorDark, globalCornerBackgroundColorDark, @"#1C1C1E")
WCR_STRING(globalCornerStrokeColorLight, globalCornerStrokeColorLight, @"#E5E5EA")
WCR_STRING(globalCornerStrokeColorDark, globalCornerStrokeColorDark, @"#3A3A3C")

// ---------------- 头像框圆角 ----------------
WCR_BOOL(avatarCornerEnabled, avatarCornerEnabled, YES)
WCR_DOUBLE(avatarCornerRadius, avatarCornerRadius, 100.0)          // 二进制默认值：100（百分比）
WCR_BOOL(avatarCornerScaleEnabled, avatarCornerScaleEnabled, NO)
WCR_DOUBLE(avatarCornerScale, avatarCornerScale, 1.0)
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

// ---------------- 资料卡 ----------------
WCR_BOOL(profileCornerEnabled, profileCornerEnabled, YES)
WCR_BOOL(profileFollowGlobalCornerEnabled, profileFollowGlobalCornerEnabled, YES)
WCR_DOUBLE(profileCornerRadius, profileCornerRadius, 16.0)
WCR_DOUBLE(profileCornerMargin, profileCornerMargin, 10.0)
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

// ---------------- 消息横幅 ----------------
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

// ---------------- 菜单 ----------------
WCR_BOOL(menuCornerEnabled, menuCornerEnabled, YES)
WCR_DOUBLE(menuCornerRadius, menuCornerRadius, 14.0)
WCR_DOUBLE(menuCornerBorderSize, menuCornerBorderSize, 0.0)
WCR_STRING(menuCornerBorderColorLight, menuCornerBorderColorLight, @"#E5E5EA")
WCR_STRING(menuCornerBorderColorDark, menuCornerBorderColorDark, @"#3A3A3C")
WCR_BOOL(plusMenuCornerEnabled, plusMenuCornerEnabled, YES)
WCR_DOUBLE(plusMenuCornerRadius, plusMenuCornerRadius, 16.0)
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

@end
