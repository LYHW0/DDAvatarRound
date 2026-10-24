// LYHWRules.h —— 「全局圆角」命中规则表（从原插件 206 个 hook 的反编译伪代码还原）
//
// 原插件做法：
//   给 UIView / UIImageView / YYAsyncImageView 这类“基类”挂 layoutSubviews，
//   靠【祖先类名】判断当前视图属于哪块界面，再套上对应半径/边框。
// 这里把“判断条件”收敛成数据，hook 只负责分发。
//
// 数值（半径/边框/颜色）一律不在规则里：规则只给 配置键前缀，数值由 LYHWConfig 提供，
// 即用户在“兰因后悟”菜单里自己设置的值。
//
// 规则字段：
//   key     配置键前缀。读取 <key>Enabled / <key>Radius / <key>BorderSize / <key>BorderColorLight|Dark
//   host    被处理的视图自身类名（空 = 不限）。支持 isKindOfClass。
//   parent  host 的父视图类名（空 = 不限）。原插件大量使用 [[self superview] class] == @"XxxCellView"
//   grand   host 的祖父视图类名（空 = 不限）
//   target  命中后真正上圆角的对象：
//             self    = host 自己
//             parent  = 父视图
//             ivar:xx = host 上名为 xx 的实例变量（如 m_imageView / _thumbImageView）
//             subs    = host 的直接子视图里属于 subClasses 的那些
//   subClasses  target==subs 时生效，类名白名单
//   clip    是否 masksToBounds

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LYHWRuleTarget) {
    LYHWRuleTargetSelf = 0,
    LYHWRuleTargetParent,
    LYHWRuleTargetIvar,
    LYHWRuleTargetSubs,
};

typedef struct {
    const char *key;        // 配置键前缀，例如 "chatImageCorner"
    const char *host;       // 宿主类名
    const char *parent;     // 父视图类名（可空）
    const char *grand;      // 祖父视图类名（可空）
    LYHWRuleTarget target;
    const char *arg;        // ivar 名 或 逗号分隔的子视图类名
} LYHWRule;

/// 全部规则（数组 + 个数）
const LYHWRule *LYHWRulesTable(NSUInteger *outCount);

/// 在 host 上依次匹配规则并应用，返回命中条数。
/// 在被 hook 的 layoutSubviews 里调用，已内置：类存在性缓存、节流、配置开关判断。
NSUInteger LYHWApplyRulesForView(UIView *host);

NS_ASSUME_NONNULL_END
