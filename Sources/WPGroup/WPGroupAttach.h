//
//  WPGroupAttach.h
//  把分组条挂到任意会话列表页
//
//  两种接法：
//  1) 主动接（推荐）：宿主在自己的会话列表 VC 里调 WPGroupAttachToViewController(self, listView)
//  2) 自动接：WPGroupInstallAutoHook() 在运行时找到微信主会话列表 VC 并自动挂上
//
//  自动接里用到的类名/选择器都写成了可配置项，微信版本换代时改这里就行。
//

#import <UIKit/UIKit.h>
#import "WPGroupPagerController.h"

NS_ASSUME_NONNULL_BEGIN

/// 把分组条 + 内容容器接到宿主 VC
/// @param hostVC   宿主的会话列表控制器
/// @param listView 宿主的会话列表（UIScrollView / UITableView），会缩到分组条下面
/// @return 分组分页容器（强引用由 hostVC 持有，作为 childViewController 挂上）
FOUNDATION_EXPORT WPGroupPagerController *_Nullable
WPGroupAttachToViewController(UIViewController *hostVC, UIView *_Nullable listView);

/// 自动挂载：hook 住配置里的类，等它的列表就绪后插分组条
void WPGroupInstallAutoHook(void);

/// 配置自动挂载的目标（不调用则用内置默认值）
/// @param className       会话列表控制器类名，默认 "NewMainFrameViewController"
/// @param listIvarNames   列表 view 的 ivar 名候选，默认 @[@"m_tableView", @"_tableView", @"tableView"]
void WPGroupSetAutoHookTarget(NSString *className, NSArray<NSString *> *listIvarNames);

NS_ASSUME_NONNULL_END
