//
//  WPGroupSettingViewController.h
//  分组设置页
//
//  逆向自 WCPulseGroupSettingViewController
//  结构：功能设置（20 行）/ 当前分组（可增删改排序）/ 重启应用
//

#import <UIKit/UIKit.h>
#import "WPGroupConfig.h"
#import "WPGroupEngine.h"

NS_ASSUME_NONNULL_BEGIN

@protocol WPGroupSettingViewControllerDelegate <NSObject>
@optional
/// 宿主自己的标签列表（微信标签名）。不实现则"标签"入口提示暂不可用
- (NSArray<NSString *> *)labelNamesForGroupSettings:(id)controller;
/// 需要重启时调用（宿主自行决定怎么重启：exit(0) / relaunch / 提示用户）
- (void)groupSettingsRequestRestart:(id)controller;
/// 设置发生任何变化（宿主在此刷新会话列表）
- (void)groupSettingsDidChange:(id)controller;
@end

@interface WPGroupSettingViewController : UIViewController

@property (nonatomic, weak, nullable) id<WPGroupSettingViewControllerDelegate> delegate;

/// 直接进编辑模式（对应插件的 needOpenEditMode）
@property (nonatomic, assign) BOOL startInEditMode;

@end

NS_ASSUME_NONNULL_END
