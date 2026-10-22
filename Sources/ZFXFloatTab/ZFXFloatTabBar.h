//
//  ZFXFloatTabBar.h
//  悬浮底栏 —— 视图与调度
//
//  结构：
//    ZFXFloatingItemButton   单个按钮（图标 + 文字 + 角标）
//    ZFXFloatingBarView      悬浮底栏本体（背景/遮罩/描边/立体/发光/动画）
//    ZFXFloatTabManager      调度：接管原生 MMTabBar、手势、调节
//

#import <UIKit/UIKit.h>
#import "ZFXFloatTabPrefs.h"

@class ZFXFloatingBarView;

// ─────────────────────────────────────────────────────────
// 按钮
// ─────────────────────────────────────────────────────────
@interface ZFXFloatingItemButton : UIControl

@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UIView      *badgeDot;
@property (nonatomic, strong) UILabel     *badgeLabel;
@property (nonatomic, strong) UIView      *selectionPill;
@property (nonatomic, assign) NSInteger   index;
@property (nonatomic, assign) BOOL        selectedState;

- (void)applyConfig:(ZFXConfig)cfg;
- (void)setSelectedState:(BOOL)selected animated:(BOOL)animated anim:(NSInteger)anim;

@end

// ─────────────────────────────────────────────────────────
// 悬浮底栏本体
// ─────────────────────────────────────────────────────────
@interface ZFXFloatingBarView : UIView
<UIGestureRecognizerDelegate>

@property (nonatomic, weak)   id                hostTabBar;     // MMTabBar
@property (nonatomic, strong) UIVisualEffectView *effectView;
@property (nonatomic, strong) UIView            *tintView;
@property (nonatomic, strong) CAGradientLayer   *highlightLayer;
@property (nonatomic, strong) UIView            *glowView;
@property (nonatomic, strong) UIView            *borderView;
@property (nonatomic, strong) UIView            *itemsContainer;
@property (nonatomic, strong) NSArray<ZFXFloatingItemButton *> *itemButtons;

/// 从原生 tabBar 同步图标/文字/选中态
- (void)reloadFromHostTabBar;

/// 应用配置并重新布局
- (void)applyConfigAndLayout:(ZFXConfig)cfg;

/// 选中下标发生变化
- (void)syncSelectedIndex:(NSInteger)index animated:(BOOL)animated;

/// 当前计算出的底栏 frame（供遮罩使用）
- (CGRect)resolvedFrameForSuperview:(UIView *)superview config:(ZFXConfig)cfg;

@end

// ─────────────────────────────────────────────────────────
// 调度
// ─────────────────────────────────────────────────────────
@interface ZFXFloatTabManager : NSObject

+ (instancetype)shared;

@property (nonatomic, assign, readonly) BOOL enabled;

/// 安装（幂等）
- (void)install;

/// MMTabBar layoutSubviews 之后调用
- (void)layoutTabBar:(id)tabBar;

/// MMTabBar 选中变化
- (void)tabBar:(id)tabBar didSelectIndex:(NSInteger)index;

/// 是否应当拦截原生背景设置（返回 YES 表示吞掉原调用）
- (BOOL)shouldSuppressNativeAppearance;

/// 重新读取配置并刷新所有底栏
- (void)reloadConfig;

/// 扩展 MMTabBar 的点击热区
- (UIView *)hitTestExtensionForTabBar:(id)tabBar point:(CGPoint)point event:(UIEvent *)event;

/// 打开调节卡片（长按弹窗）
- (void)presentQuickSettings;

@end
