//
//  WPGroupPagerController.h
//  分组分页容器
//
//  逆向自 WCSessionPagerController
//  顶部分组条 + 内容区；切分组时通知宿主刷新列表，并带过渡动画
//

#import <UIKit/UIKit.h>
#import "WPGroupSegmentedControl.h"
#import "WPGroupEngine.h"

NS_ASSUME_NONNULL_BEGIN

@class WPGroupPagerController;

@protocol WPGroupPagerControllerDelegate <NSObject>
/// 切到某个分组，宿主据此刷新自己的会话列表
- (void)pagerController:(WPGroupPagerController *)pager didSwitchToGroup:(NSString *)groupName index:(NSInteger)index;
@optional
/// 分组角标（分组名 -> 未读数），不实现则用引擎算出来的
- (NSDictionary<NSString *, NSNumber *> *)badgesForPagerController:(WPGroupPagerController *)pager;
@end

@interface WPGroupPagerController : UIViewController

@property (nonatomic, weak, nullable) id<WPGroupPagerControllerDelegate> delegate;
@property (nonatomic, strong, readonly) WPGroupSegmentedControl *segmentedControl;
/// 内容容器：宿主的会话列表加到这里
@property (nonatomic, strong, readonly) UIView *contentView;
@property (nonatomic, assign, readonly) NSInteger currentIndex;

- (instancetype)initWithDelegate:(nullable id<WPGroupPagerControllerDelegate>)delegate;

/// 分组列表变化后重建（增删分组、改名、改外观都调）
- (void)reloadSegments;
/// 切到指定分组
- (void)switchToPage:(NSInteger)index animated:(BOOL)animated;
/// 刷新角标
- (void)refreshBadges;

@end

NS_ASSUME_NONNULL_END
