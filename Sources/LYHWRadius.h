//
//  LYHWRadius.h  —  圆角 / 边框 / 祖先类判定 原语
//
//  移植自「全局圆角」插件的通用处理序列：
//      layer.cornerRadius = r; layer.masksToBounds = YES;
//      layer.borderWidth / borderColor
//  原插件在 200+ 个 hook 里反复手写这套，这里收敛成几个函数。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 套圆角 + 裁剪（radius <= 0 时取消裁剪）
void LYHWApplyRadius(UIView *_Nullable view, CGFloat radius);

/// 圆角 + 边框（borderWidth <= 0 时不画边框）
void LYHWApplyRadiusAndBorder(UIView *_Nullable view, CGFloat radius,
                              CGFloat borderWidth, UIColor *_Nullable borderColor);

/// 只圆指定的角
void LYHWApplyRadiusCorners(UIView *_Nullable view, CGFloat radius, CACornerMask corners);

/// 向上找祖先，命中类名返回 YES
BOOL LYHWViewInsideClass(UIView *_Nullable view, NSString *className);

/// 向上找祖先，命中任一类名返回 YES
BOOL LYHWViewInsideAnyClass(UIView *_Nullable view, NSArray<NSString *> *classNames);

/// 自身是否为指定类（类不存在时返回 NO，安全）
BOOL LYHWIsKindOfClassNamed(id _Nullable obj, NSString *className);

/// 递归清除子树里的毛玻璃层（底栏/顶栏背景处理用）
void LYHWRemoveVisualEffectViews(UIView *_Nullable root, int depth);

/// 递归隐藏子树里铺满的背景图（底栏/顶栏背景处理用）
void LYHWRemoveBackgroundImageViews(UIView *_Nullable root, CGFloat minWidthRatio, int depth);


NS_ASSUME_NONNULL_END
