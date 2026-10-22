//
//  WPGroupSegmentedControl.h
//  分组切换条
//
//  逆向自 WCSegmentedControl
//  功能：横向滚动分组按钮 / 线条·圆圈两种指示器 / 分组未读角标
//        点击切换 / 拖动指示器切换 / 长按（折叠置顶·快捷改值）/ 双击回到顶部
//

#import <UIKit/UIKit.h>
#import "WPGroupEngine.h"

NS_ASSUME_NONNULL_BEGIN

@class WPGroupSegmentedControl;

@protocol WPGroupSegmentedControlDelegate <NSObject>
@optional
/// 选中了某个分组
- (void)segmentedControl:(WPGroupSegmentedControl *)control didSelectIndex:(NSInteger)index;
/// 长按某个分组（默认行为：切换"折叠置顶会话"开关）
- (void)segmentedControl:(WPGroupSegmentedControl *)control didLongPressIndex:(NSInteger)index;
/// 双击某个分组（默认行为：回到该分组列表顶部）
- (void)segmentedControl:(WPGroupSegmentedControl *)control didDoubleTapIndex:(NSInteger)index;
@end

@interface WPGroupSegmentedControl : UIView

- (instancetype)initWithSegments:(NSArray<NSString *> *)segments;

@property (nonatomic, strong, readonly) UIScrollView *scrollView;
@property (nonatomic, copy) NSArray<NSString *> *segments;
@property (nonatomic, strong, readonly) NSMutableArray<UIButton *> *buttons;
@property (nonatomic, strong, readonly) UIView *indicatorView;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, weak, nullable) id<WPGroupSegmentedControlDelegate> delegate;

/// 分组名 -> 未读数（nil 表示不显示）
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSNumber *> *badges;
/// 选中变化回调（block 形式，便于分页控制器联动）
@property (nonatomic, copy, nullable) void (^selectionChanged)(NSInteger index);

/// 外部设置选中项（带动画）
- (void)selectSegmentAtIndex:(NSInteger)index animated:(BOOL)animated;
/// 重新读取配置里的颜色/字体/指示器样式（设置变更后调用）
- (void)reloadAppearance;
/// 刷新角标
- (void)refreshBadges;

/// 分组条推荐高度（含指示器）
+ (CGFloat)preferredHeight;

@end

NS_ASSUME_NONNULL_END
