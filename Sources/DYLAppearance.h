//
//  DYLAppearance.h
//  通用「自定义字体 + 自定义主题」模块（从 MiYou.dylib 的字体/主题板块逆向后重写实现）
//
//  支持：任意 iOS Tweak（Theos/Logos）或普通 App 工程
//  能力：1) 导入 ttf/otf/ttc 字体并在运行时注册，全局替换 UIFont
//        2) 导入主题包（目录或 zip），接管图片 / 颜色 / 文案，支持整体换肤
//        3) 自带一套设置界面（开关 / 字体列表 / 字号 / 主题列表 / 导入）
//
//  用法：
//    在 %ctor（tweak）或 didFinishLaunchingWithOptions（App）里调用一次：
//        #import "DYLAppearance.h"
//        DYLAppearanceStart();
//    需要界面时：
//        [DYLSettingsController presentFrom:self];
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 全局开关（编译期可裁剪）

/// 不需要字体模块就注释掉
#ifndef DYL_ENABLE_FONT
#define DYL_ENABLE_FONT 1
#endif

/// 不需要主题模块就注释掉
#ifndef DYL_ENABLE_THEME
#define DYL_ENABLE_THEME 1
#endif

#pragma mark - 配置

/// 全局配置，全部持久化到 NSUserDefaults
@interface DYLAppearanceConfig : NSObject

+ (instancetype)shared;

/// 字体
@property (nonatomic, assign) BOOL     fontEnabled;        ///< 总开关（原 mIsCustomFont）
@property (nonatomic, copy, nullable) NSString *fontPostScriptName; ///< 生效字体的 PostScript 名（原 mCustomFontName）
@property (nonatomic, copy, nullable) NSString *fontDisplayName;    ///< 显示名，仅用于界面
@property (nonatomic, assign) CGFloat  fontScale;          ///< 字号缩放，默认 1.0
@property (nonatomic, assign) BOOL     mapBoldFont;        ///< 粗体也映射成自定义字体（原 mIsSelectedCustomFont）
@property (nonatomic, assign) BOOL     overridePreferredFont; ///< 同时接管 preferredFontForTextStyle:

/// 主题
@property (nonatomic, assign) BOOL     themeEnabled;
@property (nonatomic, copy, nullable) NSString *themeName;  ///< 当前主题目录名（原 themeName）
@property (nonatomic, copy) NSArray<NSString *> *themeBackgroundClasses; ///< 需要自动铺背景图的 VC 类名

/// 全部恢复默认
- (void)resetAll;
- (void)synchronize;

@end

#pragma mark - 启动

/// 安装 hook、恢复上次的字体与主题。幂等，可重复调用。
FOUNDATION_EXPORT void DYLAppearanceStart(void);

/// 运行时重新加载（新增字体/主题后调用，模块内部也会自动调用）
FOUNDATION_EXPORT void DYLAppearanceReload(void);

#pragma mark - 工具

/// #RGB / #RRGGBB / #AARRGGBB / 0x 前缀 均可
FOUNDATION_EXPORT UIColor *_Nullable DYLColorFromHex(NSString *_Nullable hex, UIColor *_Nullable fallback);

/// 取当前主题颜色，没有就用 fallback
FOUNDATION_EXPORT UIColor *_Nullable DYLThemeColor(NSString *key, UIColor *_Nullable fallback);

/// 取当前主题图片，没有就用系统 imageNamed:
FOUNDATION_EXPORT UIImage *_Nullable DYLThemeImage(NSString *name);

#pragma mark - 设置界面

@interface DYLSettingsController : UITableViewController
/// 包一层 UINavigationController 直接弹出
+ (void)presentFrom:(UIViewController *)controller;
@end

NS_ASSUME_NONNULL_END
