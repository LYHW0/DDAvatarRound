//
//  WPGroupManager.h
//  分组模块统一入口
//
//  宿主只需要三行代码即可接入：
//    [WPGroupManager installWithProvider:self];
//    UIViewController *pager = [[WPGroupManager shared] makePagerController];
//    [[WPGroupManager shared] presentSettingsFrom:self];
//

#import <UIKit/UIKit.h>
#import "WPGroupConfig.h"
#import "WPGroupEngine.h"
#import "WPGroupPagerController.h"
#import "WPGroupSettingViewController.h"

NS_ASSUME_NONNULL_BEGIN

@protocol WPGroupManagerDelegate <NSObject>
@optional
/// 需要标签列表时提供（微信标签名）
- (NSArray<NSString *> *)labelNames;
/// 需要成员选择器时提供（微信原生多选）
- (void)presentContactPickerFrom:(UIViewController *)from
                        selected:(NSArray<NSString *> *)selected
                      completion:(void (^)(NSArray<NSString *> *wxids))completion;
/// wxid -> 显示名
- (nullable NSString *)displayNameForWxid:(NSString *)wxid;
/// 请求重启
- (void)requestRestart;
@end

@interface WPGroupManager : NSObject

+ (instancetype)shared;

/// 安装：注册会话数据源 + 应用默认分组
+ (void)installWithProvider:(id<WPGroupSessionProvider>)provider delegate:(nullable id<WPGroupManagerDelegate>)delegate;

/// 当前是否启用分组（对应"启用会话分组"开关）
@property (nonatomic, readonly) BOOL isEnabled;

/// 创建顶部带分组条的容器（宿主的会话列表塞进 pager.contentView）
- (WPGroupPagerController *)makePagerController;

/// 创建设置页（present 出来即可）
- (UIViewController *)makeSettingsViewController;

/// 从某个控制器打开设置页
- (void)presentSettingsFrom:(UIViewController *)presenter;

/// 数据变化后刷新所有分组
- (void)reload;

/// 当前分组的会话（置顶段 + 普通段）
- (NSArray<WPGroupSession *> *)currentTopSessions;
- (NSArray<WPGroupSession *> *)currentNormalSessions;

@end

NS_ASSUME_NONNULL_END
