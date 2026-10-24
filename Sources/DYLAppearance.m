//
//  DYLAppearance.m
//

#import "DYLAppearance.h"
#import "DYLFontManager.h"
#import "DYLThemeManager.h"
#import <objc/runtime.h>

static NSString *const kDYLConfigPrefix = @"dy_appearance_";

#pragma mark - 配置

@interface DYLAppearanceConfig ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@end

@implementation DYLAppearanceConfig

+ (instancetype)shared {
    static DYLAppearanceConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [[DYLAppearanceConfig alloc] init]; });
    return c;
}

- (instancetype)init {
    if ((self = [super init])) {
        _defaults = [NSUserDefaults standardUserDefaults];
        // 注意：fontScale / themeBackgroundClasses 都由自定义存取器读写，不要在这里赋 ivar
    }
    return self;
}

- (id)read:(NSString *)key {
    return [self.defaults objectForKey:[kDYLConfigPrefix stringByAppendingString:key]];
}
- (double)readDouble:(NSString *)key fallback:(double)fb {
    id v = [self read:key];
    return v ? [v doubleValue] : fb;
}
- (BOOL)readBool:(NSString *)key {
    id v = [self read:key];
    return v ? [v boolValue] : NO;
}
- (void)write:(id)value forKey:(NSString *)key {
    NSString *k = [kDYLConfigPrefix stringByAppendingString:key];
    if (value) [self.defaults setObject:value forKey:k];
    else [self.defaults removeObjectForKey:k];
}

- (BOOL)fontEnabled { return [self readBool:@"font_enabled"]; }
- (void)setFontEnabled:(BOOL)v { [self write:@(v) forKey:@"font_enabled"]; }

- (NSString *)fontPostScriptName { return [self read:@"font_name"]; }
- (void)setFontPostScriptName:(NSString *)v { [self write:v forKey:@"font_name"]; }

- (NSString *)fontDisplayName { return [self read:@"font_display"]; }
- (void)setFontDisplayName:(NSString *)v { [self write:v forKey:@"font_display"]; }

- (CGFloat)fontScale { return [self readDouble:@"font_scale" fallback:1.0]; }
- (void)setFontScale:(CGFloat)v { [self write:@(v) forKey:@"font_scale"]; }

- (BOOL)mapBoldFont { return [self readBool:@"font_bold"]; }
- (void)setMapBoldFont:(BOOL)v { [self write:@(v) forKey:@"font_bold"]; }

- (BOOL)overridePreferredFont { return [self readBool:@"font_preferred"]; }
- (void)setOverridePreferredFont:(BOOL)v { [self write:@(v) forKey:@"font_preferred"]; }

- (BOOL)themeEnabled { return [self readBool:@"theme_enabled"]; }
- (void)setThemeEnabled:(BOOL)v { [self write:@(v) forKey:@"theme_enabled"]; }

- (NSString *)themeName { return [self read:@"theme_name"]; }
- (void)setThemeName:(NSString *)v { [self write:v forKey:@"theme_name"]; }

- (NSArray<NSString *> *)themeBackgroundClasses {
    NSArray *a = [self read:@"theme_bg_classes"];
    return [a isKindOfClass:[NSArray class]] ? a : @[];
}
- (void)setThemeBackgroundClasses:(NSArray<NSString *> *)v {
    [self write:(v.count ? v : nil) forKey:@"theme_bg_classes"];
}

- (void)resetAll {
    for (NSString *key in @[ @"font_enabled", @"font_name", @"font_display", @"font_scale",
                             @"font_bold", @"font_preferred", @"theme_enabled", @"theme_name",
                             @"theme_bg_classes" ]) {
        [self write:nil forKey:key];
    }
    [self synchronize];
}

- (void)synchronize {
    [self.defaults synchronize];
}

@end

#pragma mark - 颜色

UIColor *DYLColorFromHex(NSString *hex, UIColor *fallback) {
    if (hex.length == 0) return fallback;

    NSString *s = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                   lowercaseString];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if ([s hasPrefix:@"0x"]) s = [s substringFromIndex:2];
    if (s.length == 3) { // #abc -> #aabbcc
        s = [NSString stringWithFormat:@"%c%c%c%c%c%c",
             [s characterAtIndex:0], [s characterAtIndex:0],
             [s characterAtIndex:1], [s characterAtIndex:1],
             [s characterAtIndex:2], [s characterAtIndex:2]];
    }
    if (s.length != 6 && s.length != 8) return fallback;

    unsigned long long value = 0;
    if (![[NSScanner scannerWithString:s] scanHexLongLong:&value]) return fallback;

    if (s.length == 8) { // AARRGGBB
        CGFloat a = ((value >> 24) & 0xFF) / 255.0;
        CGFloat r = ((value >> 16) & 0xFF) / 255.0;
        CGFloat g = ((value >> 8) & 0xFF) / 255.0;
        CGFloat b = (value & 0xFF) / 255.0;
        return [UIColor colorWithRed:r green:g blue:b alpha:a];
    }
    CGFloat r = ((value >> 16) & 0xFF) / 255.0;
    CGFloat g = ((value >> 8) & 0xFF) / 255.0;
    CGFloat b = (value & 0xFF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

UIColor *DYLThemeColor(NSString *key, UIColor *fallback) {
#if DYL_ENABLE_THEME
    UIColor *c = [[DYLThemeManager shared] colorForKey:key];
    return c ?: fallback;
#else
    return fallback;
#endif
}

UIImage *DYLThemeImage(NSString *name) {
#if DYL_ENABLE_THEME
    UIImage *img = [[DYLThemeManager shared] imageForKey:name];
    if (img) return img;
#endif
    return [UIImage imageNamed:name];
}

#pragma mark - 字体 hook

#if DYL_ENABLE_FONT

typedef UIFont *(*DYLFontSizeImp)(id, SEL, CGFloat);
typedef UIFont *(*DYLFontSizeWeightImp)(id, SEL, CGFloat, CGFloat);
typedef UIFont *(*DYLFontStyleImp)(id, SEL, NSString *);

static DYLFontSizeImp        dyl_orig_systemFontOfSize        = NULL;
static DYLFontSizeWeightImp  dyl_orig_systemFontOfSizeWeight  = NULL;
static DYLFontSizeImp        dyl_orig_boldSystemFontOfSize    = NULL;
static DYLFontSizeImp        dyl_orig_italicSystemFontOfSize  = NULL;
static DYLFontSizeImp        dyl_orig_fontWithSize            = NULL;
static DYLFontStyleImp       dyl_orig_preferredFontForStyle   = NULL;

static UIFont *dyl_systemFontOfSize(id self, SEL _cmd, CGFloat size) {
    UIFont *font = [[DYLFontManager shared] currentFontWithSize:size];
    if (font) return font;
    return dyl_orig_systemFontOfSize ? dyl_orig_systemFontOfSize(self, _cmd, size) : nil;
}

static UIFont *dyl_systemFontOfSizeWeight(id self, SEL _cmd, CGFloat size, CGFloat weight) {
    // 只有开了「粗体也映射」或者不是加粗请求时才替换，否则保留系统粗体的层次
    BOOL wantsBold = (weight >= UIFontWeightSemibold);
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (!wantsBold || cfg.mapBoldFont) {
        UIFont *font = [[DYLFontManager shared] currentFontWithSize:size];
        if (font) return font;
    }
    return dyl_orig_systemFontOfSizeWeight(self, _cmd, size, weight);
}

static UIFont *dyl_boldSystemFontOfSize(id self, SEL _cmd, CGFloat size) {
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (cfg.mapBoldFont) {
        UIFont *font = [[DYLFontManager shared] currentFontWithSize:size];
        if (font) return font;
    }
    return dyl_orig_boldSystemFontOfSize(self, _cmd, size);
}

static UIFont *dyl_italicSystemFontOfSize(id self, SEL _cmd, CGFloat size) {
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (cfg.mapBoldFont) {
        UIFont *font = [[DYLFontManager shared] currentFontWithSize:size];
        if (font) return font;
    }
    return dyl_orig_italicSystemFontOfSize(self, _cmd, size);
}

/// -[UIFont fontWithSize:]  已生效字体再调用会死循环，必须挡住
static UIFont *dyl_fontWithSize(id self, SEL _cmd, CGFloat size) {
    NSString *current = [[DYLFontManager shared] currentPostScriptName];
    if (current.length > 0) {
        NSString *mine = [(UIFont *)self fontName];
        UIFont *font = [[DYLFontManager shared] fontWithName:current size:size];
        if (font && ![mine isEqualToString:[font fontName]]) {
            return font;
        }
    }
    return dyl_orig_fontWithSize(self, _cmd, size);
}

static UIFont *dyl_preferredFontForTextStyle(id self, SEL _cmd, NSString *style) {
    UIFont *base = dyl_orig_preferredFontForStyle ? dyl_orig_preferredFontForStyle(self, _cmd, style) : nil;
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (cfg.overridePreferredFont) {
        UIFont *font = [[DYLFontManager shared] currentFontWithSize:base.pointSize ?: 17.0];
        if (font) return font;
    }
    return base;
}

static void DYLHookClassMethod(Class cls, SEL sel, IMP newImp, IMP *storeOrig) {
    Method m = class_getClassMethod(cls, sel);
    if (!m) return;
    IMP orig = method_setImplementation(m, newImp);
    if (storeOrig) *storeOrig = orig;
}

static void DYLHookInstanceMethod(Class cls, SEL sel, IMP newImp, IMP *storeOrig) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    IMP orig = method_setImplementation(m, newImp);
    if (storeOrig) *storeOrig = orig;
}

static void DYLInstallFontHooks(void) {
    Class UI = [UIFont class];
    DYLHookClassMethod(UI, @selector(systemFontOfSize:), (IMP)dyl_systemFontOfSize, (IMP *)&dyl_orig_systemFontOfSize);
    DYLHookClassMethod(UI, @selector(systemFontOfSize:weight:), (IMP)dyl_systemFontOfSizeWeight, (IMP *)&dyl_orig_systemFontOfSizeWeight);
    DYLHookClassMethod(UI, @selector(boldSystemFontOfSize:), (IMP)dyl_boldSystemFontOfSize, (IMP *)&dyl_orig_boldSystemFontOfSize);
    DYLHookClassMethod(UI, @selector(italicSystemFontOfSize:), (IMP)dyl_italicSystemFontOfSize, (IMP *)&dyl_orig_italicSystemFontOfSize);
    DYLHookClassMethod(UI, @selector(preferredFontForTextStyle:), (IMP)dyl_preferredFontForTextStyle, (IMP *)&dyl_orig_preferredFontForStyle);
    DYLHookInstanceMethod(UI, @selector(fontWithSize:), (IMP)dyl_fontWithSize, (IMP *)&dyl_orig_fontWithSize);
}

#endif

#pragma mark - 主题 hook

#if DYL_ENABLE_THEME

typedef UIImage *(*DYLImageNamedImp)(id, SEL, NSString *);
typedef UIImage *(*DYLImageNamedTraitImp)(id, SEL, NSString *, NSBundle *, UITraitCollection *);
static DYLImageNamedImp      dyl_orig_imageNamed      = NULL;
static DYLImageNamedTraitImp dyl_orig_imageNamedTrait = NULL;

static UIImage *dyl_imageNamed(id self, SEL _cmd, NSString *name) {
    UIImage *img = [[DYLThemeManager shared] imageForKey:name];
    if (img) return img;
    return dyl_orig_imageNamed ? dyl_orig_imageNamed(self, _cmd, name) : nil;
}

static UIImage *dyl_imageNamedTrait(id self, SEL _cmd, NSString *name, NSBundle *bundle, UITraitCollection *tc) {
    UIImage *img = [[DYLThemeManager shared] imageForKey:name];
    if (img) return img;
    return dyl_orig_imageNamedTrait ? dyl_orig_imageNamedTrait(self, _cmd, name, bundle, tc) : nil;
}

typedef void (*DYLViewDidLoadImp)(id, SEL);
static DYLViewDidLoadImp dyl_orig_viewDidLoad = NULL;

static void dyl_viewDidLoad(id self, SEL _cmd) {
    if (dyl_orig_viewDidLoad) dyl_orig_viewDidLoad(self, _cmd);

    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (!cfg.themeEnabled) return;
    if (cfg.themeBackgroundClasses.count == 0) return;

    NSString *cls = NSStringFromClass([self class]);
    for (NSString *name in cfg.themeBackgroundClasses) {
        if ([cls isEqualToString:name]) {
            [[DYLThemeManager shared] applyBackgroundToController:(UIViewController *)self];
            break;
        }
    }
}

static void DYLInstallThemeHooks(void) {
    DYLHookClassMethod([UIImage class], @selector(imageNamed:), (IMP)dyl_imageNamed, (IMP *)&dyl_orig_imageNamed);
    DYLHookClassMethod([UIImage class], @selector(imageNamed:inBundle:compatibleWithTraitCollection:),
                       (IMP)dyl_imageNamedTrait, (IMP *)&dyl_orig_imageNamedTrait);
    DYLHookInstanceMethod([UIViewController class], @selector(viewDidLoad), (IMP)dyl_viewDidLoad, (IMP *)&dyl_orig_viewDidLoad);
}

#endif

#pragma mark - 启动

static BOOL dyl_started = NO;

void DYLAppearanceStart(void) {
    if (dyl_started) return;
    dyl_started = YES;

    [[DYLAppearanceConfig shared] synchronize];

#if DYL_ENABLE_FONT
    [[DYLFontManager shared] reloadRegisteredFonts];
    DYLInstallFontHooks();
#endif

#if DYL_ENABLE_THEME
    [[DYLThemeManager shared] reloadThemes];
    DYLInstallThemeHooks();
#endif
}

void DYLAppearanceReload(void) {
#if DYL_ENABLE_FONT
    [[DYLFontManager shared] reloadRegisteredFonts];
#endif
#if DYL_ENABLE_THEME
    [[DYLThemeManager shared] reloadThemes];
#endif
}
