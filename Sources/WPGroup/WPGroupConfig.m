//
//  WPGroupConfig.m
//

#import "WPGroupConfig.h"

NSString * const WPGroupFilterSettingChanged = @"WPGroupFilterSettingChanged";
NSString * const WPGroupIndicatorSettingChanged = @"WPGroupIndicatorSettingChanged";
NSString * const WPGroupBadgeSettingChanged = @"WPGroupBadgeSettingChanged";
NSString * const WPGroupBackgroundColorSettingChanged = @"WPGroupBackgroundColorSettingChanged";
NSString * const WPGroupFontColorSettingChanged = @"WPGroupFontColorSettingChanged";
NSString * const WPGroupFontSizeSettingChanged = @"WPGroupFontSizeSettingChanged";
NSString * const WPGroupListChanged = @"WPGroupListChanged";
NSString * const WPGroupAllBadgeSettingChanged = @"WPGroupAllBadgeSettingChanged";
NSString * const WPGroupServiceAccountBadgeSettingChanged = @"WPGroupServiceAccountBadgeSettingChanged";
NSString * const WPGroupTopFilterSettingChanged = @"WPGroupTopFilterSettingChanged";
NSString * const WPGroupGlobalGestureSettingChanged = @"WPGroupGlobalGestureSettingChanged";
NSString * const WPGroupBottomBarGestureSettingChanged = @"WPGroupBottomBarGestureSettingChanged";
NSString * const WPGroupTransitionAnimationSettingChanged = @"WPGroupTransitionAnimationSettingChanged";
NSString * const WPGroupFilterDuplicateContactsSettingChanged = @"WPGroupFilterDuplicateContactsSettingChanged";
NSString * const WPGroupFoldTopSessionSettingChanged = @"WPGroupFoldTopSessionSettingChanged";
NSString * const WPGroupSessionsReloaded = @"WPGroupSessionsReloaded";

static NSArray *WPDefaultGroupList(void) {
    return @[@"全部", @"群聊", @"好友", @"服务号", @"企业号"];
}

@implementation WPGroupConfig {
    NSMutableDictionary *_cache;
}

+ (instancetype)shared {
    static WPGroupConfig *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[WPGroupConfig alloc] init]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _cache = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - 存储

- (NSString *)configFilePath {
    NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    return [[library stringByAppendingPathComponent:@"Preferences"] stringByAppendingPathComponent:@"WPGroup.plist"];
}

- (NSMutableDictionary *)configDictionary {
    if (_cache.count) return _cache;
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:self.configFilePath];
    _cache = disk ? [disk mutableCopy] : [NSMutableDictionary dictionary];
    return _cache;
}

- (void)saveConfigDictionary:(NSDictionary *)dict {
    if (!dict) return;
    _cache = [dict mutableCopy];
    NSString *path = self.configFilePath;
    NSString *dir = [path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    [_cache writeToFile:path atomically:YES];
}

#pragma mark - 通用读写

// 与原实现一致：读不到写入默认值并落盘，保证宿主随时可读
- (id)valueOrSeed:(NSString *)key default:(id)fallback {
    NSMutableDictionary *d = [self configDictionary];
    id v = d[key];
    if (!v && fallback) {
        v = fallback;
        d[key] = fallback;
        [self saveConfigDictionary:d];
    }
    return v;
}

- (BOOL)boolValueForKey:(NSString *)key default:(BOOL)def {
    return [[self valueOrSeed:key default:@(def)] boolValue];
}

- (void)setBool:(BOOL)v forKey:(NSString *)key {
    [self setConfigValue:@(v) forKey:key];
}

- (void)setConfigValue:(id)v forKey:(NSString *)key {
    NSMutableDictionary *d = [self configDictionary];
    if (v) d[key] = v; else [d removeObjectForKey:key];
    [self saveConfigDictionary:d];
}

#pragma mark - 分组列表

- (NSArray<NSString *> *)groupFilterList {
    id v = [self valueOrSeed:@"groupFilterList" default:WPDefaultGroupList()];
    return [v isKindOfClass:[NSArray class]] ? v : WPDefaultGroupList();
}
- (void)setGroupFilterList:(NSArray<NSString *> *)v {
    [self setConfigValue:(v ?: @[]) forKey:@"groupFilterList"];
}

- (NSDictionary<NSString *,NSArray<NSString *> *> *)customGroupList {
    id v = [self valueOrSeed:@"customGroupList" default:@{}];
    return [v isKindOfClass:[NSDictionary class]] ? v : @{};
}
- (void)setCustomGroupList:(NSDictionary<NSString *,NSArray<NSString *> *> *)v {
    [self setConfigValue:(v ?: @{}) forKey:@"customGroupList"];
}

- (NSDictionary<NSString *,NSString *> *)groupNameMapping {
    id v = [self valueOrSeed:@"groupNameMapping" default:@{}];
    return [v isKindOfClass:[NSDictionary class]] ? v : @{};
}
- (void)setGroupNameMapping:(NSDictionary<NSString *,NSString *> *)v {
    [self setConfigValue:(v ?: @{}) forKey:@"groupNameMapping"];
}

- (NSString *)mappedGroupName:(NSString *)name {
    if (!name.length) return @"";
    NSString *m = self.groupNameMapping[name];
    return m.length ? m : name;
}

- (NSInteger)defaultGroupIndex {
    return [[self valueOrSeed:@"defaultGroupIndex" default:@0] integerValue];
}
- (void)setDefaultGroupIndex:(NSInteger)v {
    [self setConfigValue:@(v) forKey:@"defaultGroupIndex"];
}

#pragma mark - 开关

#define WP_BOOL_PROP(getter, setter, key, def)                       \
- (BOOL)getter { return [self boolValueForKey:key default:def]; }    \
- (void)setter:(BOOL)v { [self setBool:v forKey:key]; }

WP_BOOL_PROP(enableGroupFilter, setEnableGroupFilter, @"enableGroupFilter", NO)
WP_BOOL_PROP(hideGroupIndicator, setHideGroupIndicator, @"hideGroupIndicator", NO)
WP_BOOL_PROP(hideGroupBadge, setHideGroupBadge, @"hideGroupBadge", NO)
WP_BOOL_PROP(enableTopFilter, setEnableTopFilter, @"enableTopFilter", NO)
WP_BOOL_PROP(enableGlobalSwitchGroupGesture, setEnableGlobalSwitchGroupGesture, @"enableGlobalSwitchGroupGesture", NO)
WP_BOOL_PROP(enableBottomBarSwitchGroupGesture, setEnableBottomBarSwitchGroupGesture, @"enableBottomBarSwitchGroupGesture", NO)
WP_BOOL_PROP(enableGroupTransitionAnimation, setEnableGroupTransitionAnimation, @"enableGroupTransitionAnimation", YES)
WP_BOOL_PROP(hideAllGroupBadge, setHideAllGroupBadge, @"hideAllGroupBadge", NO)
WP_BOOL_PROP(hideServiceAccountBadge, setHideServiceAccountBadge, @"hideServiceAccountBadge", NO)
WP_BOOL_PROP(hideGroupBackgroundColor, setHideGroupBackgroundColor, @"hideGroupBackgroundColor", NO)
WP_BOOL_PROP(enableFilterDuplicateContacts, setEnableFilterDuplicateContacts, @"enableFilterDuplicateContacts", NO)
WP_BOOL_PROP(disableFoldTopSession, setDisableFoldTopSession, @"disableFoldTopSession", NO)
WP_BOOL_PROP(removeServiceAccount, setRemoveServiceAccount, @"removeServiceAccount", NO)

#pragma mark - 外观

- (NSString *)colorStringForKey:(NSString *)baseKey darkKey:(NSString *)darkKey {
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }
    NSString *v = nil;
    if (dark) v = [self valueOrSeed:darkKey default:nil];
    if (!v.length) v = [self valueOrSeed:baseKey default:nil];
    return v;
}

#define WP_COLOR_PROP(getter, setter, key, def)                                  \
- (NSString *)getter {                                                           \
    id v = [self valueOrSeed:key default:def];                                   \
    return [v isKindOfClass:[NSString class]] ? v : def;                         \
}                                                                                \
- (void)setter:(NSString *)v { [self setConfigValue:v forKey:key]; }

WP_COLOR_PROP(groupBackgroundColor, setGroupBackgroundColor, @"groupBackgroundColor", @"#FFFFFF")
WP_COLOR_PROP(groupBackgroundColorDark, setGroupBackgroundColorDark, @"groupBackgroundColorDark", @"#1C1C1E")
WP_COLOR_PROP(groupIndicatorColor, setGroupIndicatorColor, @"groupIndicatorColor", @"#07C160")
WP_COLOR_PROP(groupIndicatorColorDark, setGroupIndicatorColorDark, @"groupIndicatorColorDark", @"#07C160")
WP_COLOR_PROP(groupFontColor, setGroupFontColor, @"groupFontColor", @"#07C160")
WP_COLOR_PROP(groupFontColorDark, setGroupFontColorDark, @"groupFontColorDark", @"#07C160")
WP_COLOR_PROP(groupUnselectedFontColor, setGroupUnselectedFontColor, @"groupUnselectedFontColor", @"#888888")
WP_COLOR_PROP(groupUnselectedFontColorDark, setGroupUnselectedFontColorDark, @"groupUnselectedFontColorDark", @"#98989F")

- (CGFloat)groupFontSize {
    CGFloat s = [[self valueOrSeed:@"groupFontSize" default:@(14.0)] doubleValue];
    return MIN(MAX(s, 10.0), 20.0);
}
- (void)setGroupFontSize:(CGFloat)v {
    v = MIN(MAX(v, 10.0), 20.0);
    [self setConfigValue:@(v) forKey:@"groupFontSize"];
}

- (NSInteger)groupIndicatorStyle {
    return [[self valueOrSeed:@"groupIndicatorStyle" default:@0] integerValue];
}
- (void)setGroupIndicatorStyle:(NSInteger)v {
    [self setConfigValue:@(v) forKey:@"groupIndicatorStyle"];
}

- (void)resetAppearanceDefaults {
    NSMutableDictionary *d = [self configDictionary];
    NSArray *keys = @[@"groupBackgroundColor", @"groupBackgroundColorDark",
                      @"groupIndicatorColor", @"groupIndicatorColorDark",
                      @"groupFontColor", @"groupFontColorDark",
                      @"groupUnselectedFontColor", @"groupUnselectedFontColorDark",
                      @"groupFontSize", @"groupIndicatorStyle",
                      @"hideGroupBackgroundColor", @"hideGroupIndicator"];
    for (NSString *k in keys) [d removeObjectForKey:k];
    [self saveConfigDictionary:d];
}

#pragma mark - 颜色工具

+ (UIColor *)colorFromHexString:(NSString *)hex {
    if (!hex.length) return nil;
    NSString *s = [hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if (s.length == 3) {
        s = [NSString stringWithFormat:@"%c%c%c%c%c%c",
             [s characterAtIndex:0], [s characterAtIndex:0],
             [s characterAtIndex:1], [s characterAtIndex:1],
             [s characterAtIndex:2], [s characterAtIndex:2]];
    }
    if (s.length != 6 && s.length != 8) return nil;
    unsigned long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:s];
    if (![scanner scanHexLongLong:&value]) return nil;
    CGFloat r, g, b, a = 1.0;
    if (s.length == 8) {
        a = ((value >> 24) & 0xFF) / 255.0;
        r = ((value >> 16) & 0xFF) / 255.0;
        g = ((value >> 8) & 0xFF) / 255.0;
        b = (value & 0xFF) / 255.0;
    } else {
        r = ((value >> 16) & 0xFF) / 255.0;
        g = ((value >> 8) & 0xFF) / 255.0;
        b = (value & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

+ (NSString *)hexStringFromColor:(UIColor *)color {
    if (!color) return nil;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w = 0;
        if ([color getWhite:&w alpha:&a]) { r = g = b = w; }
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)round(r * 255), (int)round(g * 255), (int)round(b * 255)];
}

@end
