//
//  ZFXFloatTabPrefs.h
//  悬浮底栏（Floating Tab Bar）复刻模块
//
//  全部配置键与原插件保持一致，直接沿用原键名，方便迁移与共存。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ── 总开关 ───────────────────────────────────────────────
extern NSString * const ZFXKeyFloatTab;          // wkkFloatTab

// ── 样式与基础 ───────────────────────────────────────────
extern NSString * const ZFXKeyStyle;             // wkkFloatTabStyle       0..3
extern NSString * const ZFXKeyNoMask;            // wkkFloatTabNoMask
extern NSString * const ZFXKeyStereo;            // wkkFloatTabStereo
extern NSString * const ZFXKeyMaskGlow;          // wkkFloatTabMaskGlow
extern NSString * const ZFXKeyLongPopup;         // wkkFloatTabLongPopup
extern NSString * const ZFXKeyMaskSlide;         // wkkFloatTabMaskSlide
extern NSString * const ZFXKeyHideDot;           // wkkFloatTabHideDot
extern NSString * const ZFXKeyHideBadge;         // wkkFloatTabHideBadge
extern NSString * const ZFXKeyHideText;          // wkkFloatTabHideText
extern NSString * const ZFXKeyIconAnim;          // wkkFloatTabIconAnim    0..5

// ── 颜色配置 ─────────────────────────────────────────────
extern NSString * const ZFXKeyBtnColor;          // wkkFloatTabBtnColor
extern NSString * const ZFXKeyMaskLight;         // wkkFloatTabMaskLight
extern NSString * const ZFXKeyMaskDark;          // wkkFloatTabMaskDark
extern NSString * const ZFXKeyBgLight;           // wkkFloatTabBgLight
extern NSString * const ZFXKeyBgDark;            // wkkFloatTabBgDark

// ── 尺寸与外观 ───────────────────────────────────────────
extern NSString * const ZFXKeyWidth;             // wkkFloatTabWidth        -50..50  def -1
extern NSString * const ZFXKeyY;                 // wkkFloatTabY            -40..40  def -4
extern NSString * const ZFXKeyHeight;            // wkkFloatTabHeight       -40..40  def 12
extern NSString * const ZFXKeyAlpha;             // wkkFloatTabAlpha          0..100 def 100
extern NSString * const ZFXKeyMaskAlpha;         // wkkFloatTabMaskAlpha      0..100 def 100
extern NSString * const ZFXKeyRadius;            // wkkFloatTabRadius       -50..50  def -1
extern NSString * const ZFXKeyButtonScale;       // wkkFloatTabButtonScale    0..100 def 0

// 设置变更通知（与原插件同名）
extern NSString * const ZFXSettingsChangedNotification; // CSFloatingTabBarSettingsChanged

// 样式枚举
typedef NS_ENUM(NSInteger, ZFXStyle) {
    ZFXStyleInitial  = 0,   // 初始样式
    ZFXStyleLiquid   = 1,   // 液态样式
    ZFXStyleCombined = 2,   // 组合样式
    ZFXStyleCustom   = 3,   // 自定义样式
};

// 一次读取出来的完整配置快照
typedef struct {
    BOOL     enabled;
    ZFXStyle style;
    BOOL     noMask, stereo, maskGlow, longPopup, maskSlide;
    BOOL     hideDot, hideBadge, hideText;
    NSInteger iconAnim;

    CGFloat  widthOffset;    // -50..50
    CGFloat  yOffset;        // -40..40
    CGFloat  heightOffset;   // -40..40
    CGFloat  alpha;          // 0..1
    CGFloat  maskAlpha;      // 0..1
    CGFloat  radiusOffset;   // -50..50
    CGFloat  buttonScale;    // 0..1

    // ARC 下 C 结构体里只能放 __unsafe_unretained 对象指针
    __unsafe_unretained UIColor *btnColor;
    __unsafe_unretained UIColor *maskLight;
    __unsafe_unretained UIColor *maskDark;
    __unsafe_unretained UIColor *bgLight;
    __unsafe_unretained UIColor *bgDark;
} ZFXConfig;

@interface ZFXPrefs : NSObject

/// 注册全部默认值（幂等，安装时调用一次）
+ (void)registerDefaults;

/// 读取完整配置
+ (ZFXConfig)config;

/// 单键读写
+ (BOOL)boolForKey:(NSString *)key def:(BOOL)def;
+ (NSInteger)intForKey:(NSString *)key def:(NSInteger)def;
+ (void)setBool:(BOOL)value forKey:(NSString *)key;
+ (void)setInt:(NSInteger)value forKey:(NSString *)key;
+ (NSString *)stringForKey:(NSString *)key;
+ (void)setString:(NSString *)value forKey:(NSString *)key;

/// "#RRGGBB" / "#RRGGBBAA" → UIColor，失败返回 fallback
+ (UIColor *)colorFromHex:(NSString *)hex fallback:(UIColor *)fallback;
+ (NSString *)hexFromColor:(UIColor *)color;

@end
