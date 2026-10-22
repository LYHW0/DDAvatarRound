//
//  ZFXFloatTabPrefs.m
//

#import "ZFXFloatTabPrefs.h"
#import <string.h>

NSString * const ZFXKeyFloatTab        = @"wkkFloatTab";
NSString * const ZFXKeyStyle           = @"wkkFloatTabStyle";
NSString * const ZFXKeyNoMask          = @"wkkFloatTabNoMask";
NSString * const ZFXKeyStereo          = @"wkkFloatTabStereo";
NSString * const ZFXKeyMaskGlow        = @"wkkFloatTabMaskGlow";
NSString * const ZFXKeyLongPopup       = @"wkkFloatTabLongPopup";
NSString * const ZFXKeyMaskSlide       = @"wkkFloatTabMaskSlide";
NSString * const ZFXKeyHideDot         = @"wkkFloatTabHideDot";
NSString * const ZFXKeyHideBadge       = @"wkkFloatTabHideBadge";
NSString * const ZFXKeyHideText        = @"wkkFloatTabHideText";
NSString * const ZFXKeyIconAnim        = @"wkkFloatTabIconAnim";
NSString * const ZFXKeyBtnColor        = @"wkkFloatTabBtnColor";
NSString * const ZFXKeyMaskLight       = @"wkkFloatTabMaskLight";
NSString * const ZFXKeyMaskDark        = @"wkkFloatTabMaskDark";
NSString * const ZFXKeyBgLight         = @"wkkFloatTabBgLight";
NSString * const ZFXKeyBgDark          = @"wkkFloatTabBgDark";
NSString * const ZFXKeyWidth           = @"wkkFloatTabWidth";
NSString * const ZFXKeyY               = @"wkkFloatTabY";
NSString * const ZFXKeyHeight          = @"wkkFloatTabHeight";
NSString * const ZFXKeyAlpha           = @"wkkFloatTabAlpha";
NSString * const ZFXKeyMaskAlpha       = @"wkkFloatTabMaskAlpha";
NSString * const ZFXKeyRadius          = @"wkkFloatTabRadius";
NSString * const ZFXKeyButtonScale     = @"wkkFloatTabButtonScale";

NSString * const ZFXSettingsChangedNotification = @"CSFloatingTabBarSettingsChanged";

@implementation ZFXPrefs

+ (NSUserDefaults *)defaults {
    return [NSUserDefaults standardUserDefaults];
}

+ (void)registerDefaults {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *defs = @{
            ZFXKeyFloatTab      : @NO,
            ZFXKeyStyle         : @(ZFXStyleInitial),
            ZFXKeyNoMask        : @NO,
            ZFXKeyStereo        : @YES,
            ZFXKeyMaskGlow      : @NO,
            ZFXKeyLongPopup     : @YES,
            ZFXKeyMaskSlide     : @YES,
            ZFXKeyHideDot       : @NO,
            ZFXKeyHideBadge     : @NO,
            ZFXKeyHideText      : @NO,
            ZFXKeyIconAnim      : @1,
            ZFXKeyWidth         : @(-1),
            ZFXKeyY             : @(-4),
            ZFXKeyHeight        : @(12),
            ZFXKeyAlpha         : @(100),
            ZFXKeyMaskAlpha     : @(100),
            ZFXKeyRadius        : @(-1),
            ZFXKeyButtonScale   : @(0),
            ZFXKeyBtnColor      : @"#FFFFFF",
            ZFXKeyMaskLight     : @"#FFFFFF",
            ZFXKeyMaskDark      : @"#000000",
            ZFXKeyBgLight       : @"#F7F7F7",
            ZFXKeyBgDark        : @"#1C1C1E",
        };
        [[self defaults] registerDefaults:defs];
    });
}

+ (BOOL)boolForKey:(NSString *)key def:(BOOL)def {
    NSUserDefaults *d = [self defaults];
    if (![d objectForKey:key]) return def;
    return [d boolForKey:key];
}

+ (NSInteger)intForKey:(NSString *)key def:(NSInteger)def {
    NSUserDefaults *d = [self defaults];
    if (![d objectForKey:key]) return def;
    return [d integerForKey:key];
}

+ (void)setBool:(BOOL)value forKey:(NSString *)key {
    [[self defaults] setBool:value forKey:key];
}

+ (void)setInt:(NSInteger)value forKey:(NSString *)key {
    [[self defaults] setInteger:value forKey:key];
}

+ (NSString *)stringForKey:(NSString *)key {
    id v = [[self defaults] objectForKey:key];
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

+ (void)setString:(NSString *)value forKey:(NSString *)key {
    [[self defaults] setObject:value forKey:key];
}

static UIColor *sBtnColor;
static UIColor *sMaskLight, *sMaskDark, *sBgLight, *sBgDark;

static UIColor *ZFXSafeColor(id value, UIColor *fallback) {
    if ([value isKindOfClass:[UIColor class]]) return (UIColor *)value;
    return fallback;
}

+ (ZFXConfig)config {
    ZFXConfig c;
    memset(&c, 0, sizeof(c));

    c.enabled   = [self boolForKey:ZFXKeyFloatTab def:NO];
    c.style     = (ZFXStyle)[self intForKey:ZFXKeyStyle def:ZFXStyleInitial];
    if (c.style < 0 || c.style > 3) c.style = ZFXStyleInitial;

    c.noMask    = [self boolForKey:ZFXKeyNoMask    def:NO];
    c.stereo    = [self boolForKey:ZFXKeyStereo    def:YES];
    c.maskGlow  = [self boolForKey:ZFXKeyMaskGlow  def:NO];
    c.longPopup = [self boolForKey:ZFXKeyLongPopup def:YES];
    c.maskSlide = [self boolForKey:ZFXKeyMaskSlide def:YES];
    c.hideDot   = [self boolForKey:ZFXKeyHideDot   def:NO];
    c.hideBadge = [self boolForKey:ZFXKeyHideBadge def:NO];
    c.hideText  = [self boolForKey:ZFXKeyHideText  def:NO];
    c.iconAnim  = [self intForKey:ZFXKeyIconAnim   def:1];
    if (c.iconAnim < 0 || c.iconAnim > 5) c.iconAnim = 0;

    c.widthOffset  = (CGFloat)[self intForKey:ZFXKeyWidth       def:-1];
    c.yOffset      = (CGFloat)[self intForKey:ZFXKeyY           def:-4];
    c.heightOffset = (CGFloat)[self intForKey:ZFXKeyHeight      def:12];
    c.alpha        = (CGFloat)[self intForKey:ZFXKeyAlpha       def:100] / 100.0;
    c.maskAlpha    = (CGFloat)[self intForKey:ZFXKeyMaskAlpha   def:100] / 100.0;
    c.radiusOffset = (CGFloat)[self intForKey:ZFXKeyRadius      def:-1];
    c.buttonScale  = (CGFloat)[self intForKey:ZFXKeyButtonScale def:0] / 100.0;

    c.alpha     = MAX(0.0, MIN(1.0, c.alpha));
    c.maskAlpha = MAX(0.0, MIN(1.0, c.maskAlpha));

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    // 不使用 labelColor 等动态 UIColor：iOS 26 的 UITraitChangeRegistry
    // 在这里会被错误桥接进 C 结构体，随后收到 UIColor 消息而崩溃。
    UIColor *defBtn = dark ? [UIColor colorWithWhite:0.95 alpha:1.0]
                           : [UIColor colorWithWhite:0.18 alpha:1.0];

    sBtnColor  = ZFXSafeColor([self colorFromHex:[self stringForKey:ZFXKeyBtnColor] fallback:defBtn], defBtn);
    sMaskLight = ZFXSafeColor([self colorFromHex:[self stringForKey:ZFXKeyMaskLight] fallback:[UIColor whiteColor]], [UIColor whiteColor]);
    sMaskDark  = ZFXSafeColor([self colorFromHex:[self stringForKey:ZFXKeyMaskDark] fallback:[UIColor blackColor]], [UIColor blackColor]);
    sBgLight   = ZFXSafeColor([self colorFromHex:[self stringForKey:ZFXKeyBgLight] fallback:[UIColor colorWithWhite:0.97 alpha:1.0]], [UIColor colorWithWhite:0.97 alpha:1.0]);
    sBgDark    = ZFXSafeColor([self colorFromHex:[self stringForKey:ZFXKeyBgDark] fallback:[UIColor colorWithWhite:0.11 alpha:1.0]], [UIColor colorWithWhite:0.11 alpha:1.0]);

    c.btnColor  = sBtnColor;
    c.maskLight = sMaskLight;
    c.maskDark  = sMaskDark;
    c.bgLight   = sBgLight;
    c.bgDark    = sBgDark;

    return c;
}

+ (UIColor *)colorFromHex:(NSString *)hex fallback:(UIColor *)fallback {
    if (![hex isKindOfClass:[NSString class]] || hex.length == 0) return fallback;

    NSString *s = [hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if ([s hasPrefix:@"0x"] || [s hasPrefix:@"0X"]) s = [s substringFromIndex:2];
    if (s.length != 6 && s.length != 8) return fallback;

    unsigned long long v = 0;
    NSScanner *scanner = [NSScanner scannerWithString:s];
    if (![scanner scanHexLongLong:&v] || !scanner.isAtEnd) return fallback;

    CGFloat r, g, b, a = 1.0;
    if (s.length == 6) {
        r = ((v >> 16) & 0xFF) / 255.0;
        g = ((v >> 8)  & 0xFF) / 255.0;
        b = ( v        & 0xFF) / 255.0;
    } else {
        r = ((v >> 24) & 0xFF) / 255.0;
        g = ((v >> 16) & 0xFF) / 255.0;
        b = ((v >> 8)  & 0xFF) / 255.0;
        a = ( v        & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

+ (NSString *)hexFromColor:(UIColor *)color {
    if (!color) return @"#FFFFFF";
    CGFloat r = 1, g = 1, b = 1, a = 1;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w = 1;
        if ([color getWhite:&w alpha:&a]) { r = g = b = w; }
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X",
            (int)lround(r * 255), (int)lround(g * 255), (int)lround(b * 255), (int)lround(a * 255)];
}

@end
