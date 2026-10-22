//
//  WPCustomGroupViewController.h
//  自定义分组编辑页
//
//  逆向自 WCPulseCustomGroupVC
//  结构：分组名称输入行 + 已选成员列表 + "添加成员"行；保存时校验名称与成员
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 保存回调：分组名 + 成员 wxid 数组
typedef void (^WPCustomGroupSaveBlock)(NSString *groupName, NSArray<NSString *> *members);

@class WPCustomGroupViewController;

@protocol WPCustomGroupViewControllerDataSource <NSObject>
@optional
/// 返回可选成员：[{@"wxid":.., @"name":..}]，不实现则用内置"输入 wxid"方式添加
- (NSArray<NSDictionary<NSString *, NSString *> *> *)selectableMembersForCustomGroup:(WPCustomGroupViewController *)vc;
/// 打开宿主自己的多选联系人界面（微信原生选择器），选完调用 completion
- (void)customGroup:(WPCustomGroupViewController *)vc
    presentPickerWithSelected:(NSArray<NSString *> *)selected
                   completion:(void (^)(NSArray<NSString *> *wxids))completion;
/// wxid -> 显示名，用于列表展示
- (nullable NSString *)customGroup:(WPCustomGroupViewController *)vc displayNameForWxid:(NSString *)wxid;
@end

@interface WPCustomGroupViewController : UIViewController

- (instancetype)initWithGroupName:(nullable NSString *)groupName;

@property (nonatomic, assign) BOOL isEditMode;
@property (nonatomic, copy, nullable) NSString *groupName;
@property (nonatomic, copy, nullable) WPCustomGroupSaveBlock saveCompletionBlock;
@property (nonatomic, weak, nullable) id<WPCustomGroupViewControllerDataSource> dataSource;

@end

NS_ASSUME_NONNULL_END
