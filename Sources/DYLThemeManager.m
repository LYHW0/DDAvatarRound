//
//  DYLThemeManager.m
//

#import "DYLThemeManager.h"
#import "DYLAppearance.h"
#import <objc/runtime.h>
#include <zlib.h>

#if __has_include(<SSZipArchive/SSZipArchive.h>)
#import <SSZipArchive/SSZipArchive.h>
#define DYL_HAS_SSZIPARCHIVE 1
#else
#define DYL_HAS_SSZIPARCHIVE 0
#endif


#pragma mark - 内置 ZIP 解压（Store + Deflate）

static uint16_t DYLZip16(const uint8_t *p) { return (uint16_t)p[0] | ((uint16_t)p[1] << 8); }
static uint32_t DYLZip32(const uint8_t *p) { return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24); }

static BOOL DYLZipSafeRelativePath(NSString *name) {
    if (name.length == 0 || [name hasPrefix:@"/"] || [name containsString:@":" ] || [name containsString:@".."])
        return NO;
    return YES;
}

static NSData *DYLZipInflate(NSData *compressed, NSUInteger outputSize) {
    if (outputSize > 256 * 1024 * 1024) return nil;
    NSMutableData *out = [NSMutableData dataWithLength:outputSize];
    z_stream stream = {0};
    stream.next_in = (Bytef *)compressed.bytes;
    stream.avail_in = (uInt)MIN(compressed.length, UINT_MAX);
    stream.next_out = out.mutableBytes;
    stream.avail_out = (uInt)MIN(outputSize, UINT_MAX);
    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) return nil;
    int result = inflate(&stream, Z_FINISH);
    inflateEnd(&stream);
    if (result != Z_STREAM_END || stream.total_out != outputSize) return nil;
    return out;
}

static BOOL DYLUnzipArchive(NSString *source, NSString *destination, NSString **message) {
    NSData *data = [NSData dataWithContentsOfFile:source];
    if (data.length < 22) { if (message) *message = @"ZIP 文件太小或已损坏"; return NO; }
    const uint8_t *bytes = data.bytes; NSUInteger length = data.length;
    NSUInteger searchStart = length > (65535 + 22) ? length - (65535 + 22) : 0;
    NSUInteger eocd = NSNotFound;
    for (NSUInteger i = length - 22; i >= searchStart; i--) {
        if (DYLZip32(bytes + i) == 0x06054b50) { eocd = i; break; }
        if (i == 0) break;
    }
    if (eocd == NSNotFound) { if (message) *message = @"找不到 ZIP 目录"; return NO; }
    uint16_t count = DYLZip16(bytes + eocd + 10);
    uint32_t centralSize = DYLZip32(bytes + eocd + 12);
    uint32_t centralOffset = DYLZip32(bytes + eocd + 16);
    if ((uint64_t)centralOffset + centralSize > length || count > 10000) { if (message) *message = @"ZIP 目录无效"; return NO; }
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:NULL];
    NSUInteger pos = centralOffset;
    for (uint16_t index = 0; index < count; index++) {
        if (pos + 46 > length || DYLZip32(bytes + pos) != 0x02014b50) { if (message) *message = @"ZIP 条目损坏"; return NO; }
        uint16_t method = DYLZip16(bytes + pos + 10);
        uint32_t compressedSize = DYLZip32(bytes + pos + 20);
        uint32_t uncompressedSize = DYLZip32(bytes + pos + 24);
        uint16_t nameLen = DYLZip16(bytes + pos + 28);
        uint16_t extraLen = DYLZip16(bytes + pos + 30);
        uint16_t commentLen = DYLZip16(bytes + pos + 32);
        uint32_t localOffset = DYLZip32(bytes + pos + 42);
        if (pos + 46 + nameLen + extraLen + commentLen > length) return NO;
        NSString *name = [[NSString alloc] initWithBytes:bytes + pos + 46 length:nameLen encoding:NSUTF8StringEncoding];
        if (!name) name = [[NSString alloc] initWithBytes:bytes + pos + 46 length:nameLen encoding:NSASCIIStringEncoding];
        if (!DYLZipSafeRelativePath(name)) { if (message) *message = @"ZIP 包含不安全路径"; return NO; }
        NSString *target = [destination stringByAppendingPathComponent:name];
        BOOL directory = [name hasSuffix:@"/"];
        if (directory) {
            [fm createDirectoryAtPath:target withIntermediateDirectories:YES attributes:nil error:NULL];
        } else {
            if (localOffset + 30 > length || DYLZip32(bytes + localOffset) != 0x04034b50) return NO;
            uint16_t localNameLen = DYLZip16(bytes + localOffset + 26);
            uint16_t localExtraLen = DYLZip16(bytes + localOffset + 28);
            uint64_t payload = (uint64_t)localOffset + 30 + localNameLen + localExtraLen;
            if (payload + compressedSize > length) return NO;
            NSData *packed = [data subdataWithRange:NSMakeRange((NSUInteger)payload, compressedSize)];
            NSData *fileData = method == 0 ? packed : (method == 8 ? DYLZipInflate(packed, uncompressedSize) : nil);
            if (!fileData) { if (message) *message = @"主题 ZIP 使用了不支持的压缩方式"; return NO; }
            NSString *parent = [target stringByDeletingLastPathComponent];
            [fm createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:NULL];
            if (![fileData writeToFile:target options:NSDataWritingAtomic error:NULL]) return NO;
        }
        pos += 46 + nameLen + extraLen + commentLen;
    }
    return YES;
}

#pragma mark - DYLTheme

@interface DYLTheme ()
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *colors;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *images;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *strings;
@end

@implementation DYLTheme

+ (instancetype)themeAtPath:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *jsonPath = [path stringByAppendingPathComponent:@"theme.json"];
    NSString *plistPath = [path stringByAppendingPathComponent:@"Theme.plist"];
    NSDictionary *root = nil;

    if ([fm fileExistsAtPath:jsonPath]) {
        NSData *data = [NSData dataWithContentsOfFile:jsonPath];
        if (data) {
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if ([obj isKindOfClass:[NSDictionary class]]) root = obj;
        }
    }
    if (!root && [fm fileExistsAtPath:plistPath]) {
        id obj = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        if ([obj isKindOfClass:[NSDictionary class]]) root = obj;
    }
    if (![root isKindOfClass:[NSDictionary class]]) return nil;

    DYLTheme *theme = [[DYLTheme alloc] init];
    theme.path = path;
    theme.identifier = path.lastPathComponent;
    theme.name = [root[@"name"] isKindOfClass:[NSString class]] ? root[@"name"] : theme.identifier;
    theme.colors = [root[@"colors"] isKindOfClass:[NSDictionary class]] ? root[@"colors"] : @{};
    theme.images = [root[@"images"] isKindOfClass:[NSDictionary class]] ? root[@"images"] : @{};
    theme.strings = [root[@"strings"] isKindOfClass:[NSDictionary class]] ? root[@"strings"] : @{};
    return theme;
}

- (NSString *)imagePathForKey:(NSString *)key {
    NSString *file = self.images[key];
    if (file.length == 0) return nil;
    if ([file isAbsolutePath]) return file;

    NSString *p = [self.path stringByAppendingPathComponent:file];
    if ([[NSFileManager defaultManager] fileExistsAtPath:p]) return p;

    // 允许省略扩展名
    for (NSString *ext in @[ @"png", @"jpg", @"jpeg", @"pdf", @"svg" ]) {
        NSString *q = [p stringByAppendingPathExtension:ext];
        if ([[NSFileManager defaultManager] fileExistsAtPath:q]) return q;
    }
    return nil;
}

@end

#pragma mark - DYLThemeManager

@interface DYLThemeManager ()
@property (nonatomic, copy) NSArray<DYLTheme *> *themes;
@property (nonatomic, strong) DYLTheme *currentTheme;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIImage *> *imageCache;
@end

@implementation DYLThemeManager

+ (instancetype)shared {
    static DYLThemeManager *m = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [[DYLThemeManager alloc] init]; });
    return m;
}

- (instancetype)init {
    if ((self = [super init])) {
        _imageCache = [NSMutableDictionary dictionary];
        [[NSFileManager defaultManager] createDirectoryAtPath:self.themesDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
    return self;
}

- (NSString *)themesDirectory {
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [doc stringByAppendingPathComponent:@"DYLAppearance/Themes"];
}

#pragma mark - 加载

- (void)reloadThemes {
    NSMutableArray *list = [NSMutableArray array];
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.themesDirectory error:NULL];
    for (NSString *dir in names) {
        NSString *path = [self.themesDirectory stringByAppendingPathComponent:dir];
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || !isDir) continue;
        DYLTheme *t = [DYLTheme themeAtPath:path];
        if (t) [list addObject:t];
    }
    [list sortUsingComparator:^NSComparisonResult(DYLTheme *a, DYLTheme *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    self.themes = list;
    [self.imageCache removeAllObjects];

    // 恢复上次选中的主题
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (cfg.themeEnabled && cfg.themeName.length > 0) {
        for (DYLTheme *t in list) {
            if ([t.identifier isEqualToString:cfg.themeName]) {
                self.currentTheme = t;
                break;
            }
        }
    }
}

#pragma mark - 导入 / 删除

- (BOOL)importThemeAtURL:(NSURL *)url error:(NSError **)error {
    if (!url) return NO;

    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dyl_theme_import"];
    [fm removeItemAtPath:tmpDir error:NULL];
    [fm createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:NULL];

    NSString *source = url.path;
    BOOL isDir = NO;
    BOOL ok = NO;
    NSString *unzipRoot = tmpDir;
    NSString *lastError = nil;

    if ([fm fileExistsAtPath:source isDirectory:&isDir] && isDir) {
        // 直接是目录：把内容拷到临时目录
        for (NSString *item in [fm contentsOfDirectoryAtPath:source error:NULL]) {
            [fm copyItemAtPath:[source stringByAppendingPathComponent:item]
                        toPath:[tmpDir stringByAppendingPathComponent:item]
                         error:NULL];
        }
        ok = YES;
    } else {
        NSString *ext = source.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"zip"]) {
#if DYL_HAS_SSZIPARCHIVE
            ok = [SSZipArchive unzipFileAtPath:source toDestination:unzipRoot];
            if (!ok) lastError = @"解压失败";
#else
            ok = DYLUnzipArchive(source, unzipRoot, &lastError);
#endif
        } else {
            lastError = @"只支持主题目录或 zip";
        }
    }

    if (scoped) [url stopAccessingSecurityScopedResource];
    if (!ok) {
        if (error) {
            *error = [NSError errorWithDomain:@"DYLThemeManager" code:-1
                                     userInfo:@{NSLocalizedDescriptionKey : lastError ?: @"导入失败"}];
        }
        return NO;
    }

    // 找到含 theme.json 的那一层（zip 里可能套了一层文件夹）
    NSString *themeRoot = nil;
    if ([fm fileExistsAtPath:[unzipRoot stringByAppendingPathComponent:@"theme.json"]]) {
        themeRoot = unzipRoot;
    } else if ([fm fileExistsAtPath:[unzipRoot stringByAppendingPathComponent:@"Theme.plist"]]) {
        themeRoot = unzipRoot;
    } else {
        for (NSString *sub in [fm contentsOfDirectoryAtPath:unzipRoot error:NULL]) {
            NSString *p = [unzipRoot stringByAppendingPathComponent:sub];
            BOOL d = NO;
            if ([fm fileExistsAtPath:p isDirectory:&d] && d) {
                if ([fm fileExistsAtPath:[p stringByAppendingPathComponent:@"theme.json"]]) { themeRoot = p; break; }
            }
        }
    }

    if (!themeRoot) {
        if (error) {
            *error = [NSError errorWithDomain:@"DYLThemeManager" code:-2
                                     userInfo:@{NSLocalizedDescriptionKey : @"主题包里找不到 theme.json"}];
        }
        return NO;
    }

    DYLTheme *theme = [DYLTheme themeAtPath:themeRoot];
    NSString *ident = theme.identifier.length > 0 ? theme.identifier : [NSUUID UUID].UUIDString;
    NSString *dst = [self.themesDirectory stringByAppendingPathComponent:ident];
    [fm removeItemAtPath:dst error:NULL];
    ok = [fm moveItemAtPath:themeRoot toPath:dst error:NULL];

    if (!ok) {
        if (error) {
            *error = [NSError errorWithDomain:@"DYLThemeManager" code:-3
                                     userInfo:@{NSLocalizedDescriptionKey : @"写入主题目录失败"}];
        }
        return NO;
    }

    [self reloadThemes];

    DYLTheme *installed = nil;
    for (DYLTheme *t in self.themes) {
        if ([t.identifier isEqualToString:ident]) { installed = t; break; }
    }
    if (installed) [self activateTheme:installed];
    return installed != nil;
}

- (BOOL)removeThemeWithIdentifier:(NSString *)identifier error:(NSError **)error {
    if (identifier.length == 0) return NO;
    NSString *path = [self.themesDirectory stringByAppendingPathComponent:identifier];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;

    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if ([cfg.themeName isEqualToString:identifier]) {
        cfg.themeEnabled = NO;
        cfg.themeName = nil;
        [cfg synchronize];
        self.currentTheme = nil;
    }
    BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:path error:error];
    [self reloadThemes];
    return ok;
}

#pragma mark - 切换

- (void)activateTheme:(DYLTheme *)theme {
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    self.currentTheme = theme;
    [self.imageCache removeAllObjects];

    if (theme) {
        cfg.themeEnabled = YES;
        cfg.themeName = theme.identifier;
    } else {
        cfg.themeEnabled = NO;
        cfg.themeName = nil;
    }
    [cfg synchronize];

    // 让已经显示的界面刷新（导航栏 / 状态栏）
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                [w setNeedsLayout];
                [w layoutIfNeeded];
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DYLThemeDidChangeNotification" object:nil];
    });
}

#pragma mark - 取资源

- (UIImage *)imageForKey:(NSString *)key {
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (!cfg.themeEnabled || !self.currentTheme) return nil;

    UIImage *cached = self.imageCache[key];
    if (cached) return cached;

    NSString *path = [self.currentTheme imagePathForKey:key];
    if (!path) return nil;

    UIImage *img = [UIImage imageWithContentsOfFile:path];
    if (!img) {
        // PDF / SVG 之类交给系统
        img = [UIImage imageNamed:path];
    }
    if (img) self.imageCache[key] = img;
    return img;
}

- (UIColor *)colorForKey:(NSString *)key {
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (!cfg.themeEnabled || !self.currentTheme) return nil;
    NSString *hex = self.currentTheme.colors[key];
    if (hex.length == 0) return nil;
    return DYLColorFromHex(hex, nil);
}

- (NSString *)stringForKey:(NSString *)key {
    DYLAppearanceConfig *cfg = [DYLAppearanceConfig shared];
    if (!cfg.themeEnabled || !self.currentTheme) return nil;
    return self.currentTheme.strings[key];
}

#pragma mark - 背景

static const void *kDYLThemeBackgroundImageView = &kDYLThemeBackgroundImageView;

- (void)applyBackgroundToController:(UIViewController *)controller {
    if (!controller.isViewLoaded) return;

    UIImage *bg = [self imageForKey:@"background"];
    UIView *existing = objc_getAssociatedObject(controller, kDYLThemeBackgroundImageView);

    if (!bg) {
        [existing removeFromSuperview];
        objc_setAssociatedObject(controller, kDYLThemeBackgroundImageView, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    UIImageView *iv = (UIImageView *)existing;
    if (!iv) {
        iv = [[UIImageView alloc] initWithFrame:controller.view.bounds];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        iv.userInteractionEnabled = NO;
        [controller.view insertSubview:iv atIndex:0];
        objc_setAssociatedObject(controller, kDYLThemeBackgroundImageView, iv, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    iv.image = bg;
    iv.frame = controller.view.bounds;
}

@end
