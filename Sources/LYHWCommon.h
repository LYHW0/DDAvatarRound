//
//  LYHWCommon.h
//  LYHW
//
//  公共工具：颜色解析、深浅色适配、视图遍历、安全调用
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// 是否深色模式
BOOL LYHWIsDarkMode(void);

/// 从 #RRGGBB / #RRGGBBAA / RRGGBB 解析颜色，非法返回 fallback
UIColor *LYHWColorFromHex(NSString *hex, UIColor *fallback);

/// 深浅色取色
UIColor *LYHWColorForAppearance(NSString *lightHex, NSString *darkHex);

/// 把颜色转成 #RRGGBB（用于设置界面回显）
NSString *LYHWHexFromColor(UIColor *color);

/// 给某个视图套用圆角 + 连续曲率 + 描边
void LYHWApplyCorner(UIView *view,
                    CGFloat radius,
                    CGFloat borderWidth,
                    UIColor * _Nullable borderColor,
                    BOOL clip);

/// 给图片视图套用圆角（不改 masksToBounds 之外的属性）
void LYHWApplyCornerToImageView(UIImageView *imageView, CGFloat radius, CGFloat borderWidth, UIColor *borderColor);

/// 递归给视图树里的 UILabel 上色（资料卡/菜单用）
void LYHWTintLabels(UIView *root, UIColor *color, NSArray<NSString *> * _Nullable skipClassNames);

/// 取视图自身或子视图里第一个指定类名的实例
UIView *LYHWFirstSubviewOfClass(UIView *root, Class cls);

/// 视图中心安全区（避免裁到导航栏）
CGRect LYHWSafeBounds(UIView *view);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
