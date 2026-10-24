//
//  DYLFontManager.h
//  字体：导入 / 注册 / 全局替换
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYLFontManager : NSObject

+ (instancetype)shared;

/// 字体存放目录 Documents/DYLAppearance/Fonts
@property (nonatomic, copy, readonly) NSString *fontsDirectory;

/// 已注册成功的自定义字体（PostScript 名，去重、排序）
@property (nonatomic, copy, readonly) NSArray<NSString *> *registeredFontNames;

/// 系统可用字体家族（排在前面的选择界面用）
@property (nonatomic, copy, readonly) NSArray<NSString *> *systemFontFamilies;

/// 扫描目录并注册全部字体（启动时自动调用）
- (void)reloadRegisteredFonts;

/// 导入一个字体文件：拷贝到 fontsDirectory 后立即注册
- (BOOL)importFontAtURL:(NSURL *)url error:(NSError *_Nullable *_Nullable)error;

/// 删除某个已导入字体（按 PostScript 名）
- (BOOL)removeFontNamed:(NSString *)postScriptName error:(NSError *_Nullable *_Nullable)error;

/// 当前应当生效的字体；没开启或找不到返回 nil（调用方回落到原实现）
- (nullable UIFont *)currentFontWithSize:(CGFloat)size;

/// 当前生效字体的 PostScript 名
- (nullable NSString *)currentPostScriptName;

/// 按名字取字体（已注册字体 or 系统字体），找不到返回 nil
- (nullable UIFont *)fontWithName:(NSString *)name size:(CGFloat)size;

@end

NS_ASSUME_NONNULL_END
