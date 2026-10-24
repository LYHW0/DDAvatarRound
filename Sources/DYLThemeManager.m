//
//  DYLThemeManager.m
//

#import "DYLThemeManager.h"
#import "DYLAppearance.h"
#import <objc/runtime.h>

#if __has_include(<SSZipArchive/SSZipArchive.h>)
#import <SSZipArchive/SSZipArchive.h>
#define DYL_HAS_SSZIPARCHIVE 1
#else
#define DYL_HAS_SSZIPARCHIVE 0
#endif

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
            lastError = @"工程里没有解压库（加 SSZipArchive 即可支持 zip，或直接把主题目录拷进来）";
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
