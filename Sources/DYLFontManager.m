//
//  DYLFontManager.m
//

#import "DYLFontManager.h"
#import "DYLAppearance.h"
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>

static NSString *const kDYLFontIndexKey = @"dy_font_index"; // { postScriptName : fileName }

@interface DYLFontManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *index; // psName -> fileName
@property (nonatomic, strong) NSMutableArray<NSString *> *names;
@end

@implementation DYLFontManager

+ (instancetype)shared {
    static DYLFontManager *m = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [[DYLFontManager alloc] init]; });
    return m;
}

- (instancetype)init {
    if ((self = [super init])) {
        _index = [NSMutableDictionary dictionary];
        _names = [NSMutableArray array];
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDYLFontIndexKey];
        if ([saved isKindOfClass:[NSDictionary class]]) {
            [_index addEntriesFromDictionary:saved];
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:self.fontsDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
    return self;
}

#pragma mark - 路径

- (NSString *)fontsDirectory {
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [doc stringByAppendingPathComponent:@"DYLAppearance/Fonts"];
}

#pragma mark - 注册

/// 从一个字体文件注册字体，返回 PostScript 名（注册失败但能取到名字也会返回名字）
static NSString *_Nullable DYLRegisterFontAtPath(NSString *path, BOOL *didRegister) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) return nil;

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    if (!provider) return nil;

    CGFontRef font = CGFontCreateWithDataProvider(provider);
    CGDataProviderRelease(provider);
    if (!font) return nil;

    NSString *psName = nil;
    CFStringRef ps = CGFontCopyPostScriptName(font);
    if (ps) {
        psName = (__bridge_transfer NSString *)ps;
    }

    CFErrorRef error = NULL;
    BOOL ok = CTFontManagerRegisterGraphicsFont(font, &error);
    if (error) CFRelease(error);
    CGFontRelease(font);

    if (didRegister) *didRegister = ok;
    return (psName.length > 0) ? psName : nil;
}

- (void)reloadRegisteredFonts {
    [self.names removeAllObjects];

    NSMutableDictionary *valid = [NSMutableDictionary dictionary];

    // 1. 之前导入过的
    for (NSString *psName in self.index.allKeys) {
        NSString *file = self.index[psName];
        NSString *path = [self.fontsDirectory stringByAppendingPathComponent:file];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) continue;

        BOOL ok = NO;
        NSString *name = DYLRegisterFontAtPath(path, &ok);
        NSString *finalName = name ?: psName;
        if (name.length == 0 && !ok) continue;
        valid[finalName] = file;
        if (![self.names containsObject:finalName]) [self.names addObject:finalName];
    }

    // 2. 目录里新丢进去、还没登记的
    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.fontsDirectory error:NULL];
    NSSet *allowed = [NSSet setWithObjects:@"ttf", @"otf", @"ttc", @"otc", @"woff", @"woff2", nil];
    for (NSString *file in files) {
        if (![allowed containsObject:file.pathExtension.lowercaseString]) continue;
        if ([valid.allValues containsObject:file]) continue;

        NSString *path = [self.fontsDirectory stringByAppendingPathComponent:file];
        BOOL ok = NO;
        NSString *name = DYLRegisterFontAtPath(path, &ok);
        if (name.length == 0) continue;
        valid[name] = file;
        if (![self.names containsObject:name]) [self.names addObject:name];
    }

    [self.index removeAllObjects];
    [self.index addEntriesFromDictionary:valid];
    [[NSUserDefaults standardUserDefaults] setObject:self.index forKey:kDYLFontIndexKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self.names sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    _registeredFontNames = [self.names copy];
}

#pragma mark - 导入 / 删除

- (BOOL)importFontAtURL:(NSURL *)url error:(NSError **)error {
    if (!url) return NO;

    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSString *name = url.lastPathComponent;
    NSString *dst = [self.fontsDirectory stringByAppendingPathComponent:name];
    NSFileManager *fm = [NSFileManager defaultManager];

    if ([fm fileExistsAtPath:dst]) [fm removeItemAtPath:dst error:NULL];

    NSError *e = nil;
    BOOL ok = [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:dst] error:&e];
    if (scoped) [url stopAccessingSecurityScopedResource];

    if (!ok) {
        if (error) *error = e;
        return NO;
    }

    BOOL didRegister = NO;
    NSString *psName = DYLRegisterFontAtPath(dst, &didRegister);
    if (psName.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"DYLFontManager" code:-1
                                     userInfo:@{NSLocalizedDescriptionKey : @"这个文件不是有效的字体"}];
        }
        [fm removeItemAtPath:dst error:NULL];
        return NO;
    }

    self.index[psName] = name;
    [[NSUserDefaults standardUserDefaults] setObject:self.index forKey:kDYLFontIndexKey];
    [self reloadRegisteredFonts];

    // 导入后直接生效
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    cfg.fontEnabled = YES;
    cfg.fontPostScriptName = psName;
    cfg.fontDisplayName = psName;
    [cfg synchronize];
    return YES;
}

- (BOOL)removeFontNamed:(NSString *)postScriptName error:(NSError **)error {
    NSString *file = self.index[postScriptName];
    if (file.length == 0) return NO;
    NSString *path = [self.fontsDirectory stringByAppendingPathComponent:file];
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];

    [self.index removeObjectForKey:postScriptName];
    [[NSUserDefaults standardUserDefaults] setObject:self.index forKey:kDYLFontIndexKey];

    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if ([cfg.fontPostScriptName isEqualToString:postScriptName]) {
        cfg.fontPostScriptName = nil;
        cfg.fontEnabled = NO;
        [cfg synchronize];
    }
    [self reloadRegisteredFonts];
    return YES;
}

#pragma mark - 取字体

- (NSString *)currentPostScriptName {
#if DYL_ENABLE_FONT
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (!cfg.fontEnabled) return nil;
    return cfg.fontPostScriptName;
#else
    return nil;
#endif
}

- (UIFont *)fontWithName:(NSString *)name size:(CGFloat)size {
    if (name.length == 0) return nil;

    UIFont *font = [UIFont fontWithName:name size:size];
    if (font) return font;

    // 传进来的是家族名（比如 "PingFang SC"）时，取家族里第一个具体字体
    NSArray<NSString *> *familyFonts = [UIFont fontNamesForFamilyName:name];
    if (familyFonts.count > 0) {
        for (NSString *n in familyFonts) {
            UIFont *f = [UIFont fontWithName:n size:size];
            if (f) return f;
        }
    }
    return nil;
}

- (UIFont *)currentFontWithSize:(CGFloat)size {
#if DYL_ENABLE_FONT
    NSString *psName = [self currentPostScriptName];
    if (psName.length == 0) return nil;

    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    CGFloat scale = cfg.fontScale > 0.05 ? cfg.fontScale : 1.0;
    CGFloat real = MAX(8.0, round(size * scale));
    if (fabs(size - real) < 0.01) real = size;

    return [self fontWithName:psName size:real];
#else
    return nil;
#endif
}

- (NSArray<NSString *> *)systemFontFamilies {
    return [UIFont.familyNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

@end
