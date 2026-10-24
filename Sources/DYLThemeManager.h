//
//  DYLThemeManager.h
//  主题：主题包解析 / 换肤 / 图片与颜色接管
//
//  主题包 = 一个目录，里面必须有 theme.json：
//  {
//    "name": "暗夜",
//    "version": "1.0",
//    "colors": { "nav_bg": "#1B1B1F", "cell_bg": "#242429", "text": "#EDEDED" },
//    "images": { "background": "bg.png", "send_btn": "icon_send.png" },
//    "strings": { "title": "聊天" }
//  }
//  images 里的文件名相对于主题目录，可以带子目录。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYLTheme : NSObject
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *identifier; ///< 目录名
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *colors;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *images;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *strings;

+ (nullable instancetype)themeAtPath:(NSString *)path;
- (nullable NSString *)imagePathForKey:(NSString *)key;
@end

@interface DYLThemeManager : NSObject

+ (instancetype)shared;

/// Documents/DYLAppearance/Themes
@property (nonatomic, copy, readonly) NSString *themesDirectory;

@property (nonatomic, copy, readonly) NSArray<DYLTheme *> *themes;
@property (nonatomic, strong, readonly, nullable) DYLTheme *currentTheme;

- (void)reloadThemes;

/// 导入主题包（目录或 zip；zip 需要工程里有 SSZipArchive）
- (BOOL)importThemeAtURL:(NSURL *)url error:(NSError *_Nullable *_Nullable)error;
- (BOOL)removeThemeWithIdentifier:(NSString *)identifier error:(NSError *_Nullable *_Nullable)error;

/// 切换主题，传 nil 关闭
- (void)activateTheme:(nullable DYLTheme *)theme;

/// 取主题资源
- (nullable UIImage *)imageForKey:(NSString *)key;
- (nullable UIColor *)colorForKey:(NSString *)key;
- (nullable NSString *)stringForKey:(NSString *)key;

/// 给控制器铺主题背景图（key = "background"）
- (void)applyBackgroundToController:(UIViewController *)controller;

@end

NS_ASSUME_NONNULL_END
